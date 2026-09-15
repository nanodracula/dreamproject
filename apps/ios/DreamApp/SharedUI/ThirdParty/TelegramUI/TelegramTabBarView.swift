// Telegram-iOS source port, GPL-2.0-or-later.
// Upstream: 6ad963e5b62d354da79040f388ae2b9132fb17b8
// TabBarComponent.View: selection, context activation, width allocation and lens layout.
// Port: ComponentFlow/Telegram theme and item nodes are replaced by UIKit adapters.
// App-specific search, avatar, badge and Lottie item content is not included.
// DreamApp customization: icon-only items with equal widths; titles remain accessible.

import UIKit

struct TelegramTabBarItem {
    let id: AnyHashable
    let title: String
    let image: UIImage?
    let selectedImage: UIImage?
    let contextActions: [TelegramContextMenuAction]
}

final class TelegramTabBarView: UIView, UIGestureRecognizerDelegate {
    private let backgroundContainer: GlassBackgroundContainerView
    private let liquidLensView: LiquidLensView
    private let contextGestureContainerView: UIView
    private let contextGesture: ContextGesture
    private var tabSelectionRecognizer: TabSelectionRecognizer!
    private var itemViews: [AnyHashable: TelegramTabBarItemView] = [:]
    private var selectedItemViews: [AnyHashable: TelegramTabBarItemView] = [:]
    private var itemWithActiveContextGesture: AnyHashable?
    private var selectionGestureState: (startX: CGFloat, currentX: CGFloat, itemWidth: CGFloat, itemId: AnyHashable)?
    private var overrideSelectedItemId: AnyHashable?
    private var menu: TelegramContextMenu?
    private var items: [TelegramTabBarItem] = []
    private var selectedId: AnyHashable?
    private var reduceMotion = false
    var selectionChanged: ((AnyHashable) -> Void)?

    override init(frame: CGRect) {
        self.backgroundContainer = GlassBackgroundContainerView()
        self.liquidLensView = LiquidLensView(kind: .externalContainer)
        self.contextGestureContainerView = UIView()
        self.contextGesture = ContextGesture(target: nil, action: nil)
        super.init(frame: frame)

        self.traitOverrides.verticalSizeClass = .compact
        self.traitOverrides.horizontalSizeClass = .compact
        self.addSubview(self.backgroundContainer)
        self.backgroundContainer.contentView.addSubview(self.contextGestureContainerView)
        self.contextGestureContainerView.addSubview(self.liquidLensView)
        let tabSelectionRecognizer = TabSelectionRecognizer(target: self, action: #selector(self.onTabSelectionGesture(_:)))
        tabSelectionRecognizer.delegate = self
        self.tabSelectionRecognizer = tabSelectionRecognizer
        self.contextGestureContainerView.addGestureRecognizer(tabSelectionRecognizer)
        self.contextGestureContainerView.addGestureRecognizer(self.contextGesture)

        self.contextGesture.shouldBegin = { [weak self] point in
            guard let self else { return false }
            if let itemId = self.item(at: point) {
                guard let item = self.items.first(where: { $0.id == itemId }) else { return false }
                if item.contextActions.isEmpty { return false }
                self.itemWithActiveContextGesture = itemId
                let startPoint = point
                self.contextGesture.externalUpdated = { [weak self] _, point in
                    guard let self else { return }
                    let dist = sqrt(pow(startPoint.x - point.x, 2.0) + pow(startPoint.y - point.y, 2.0))
                    if dist > 10.0 { self.contextGesture.cancel() }
                }
                return true
            }
            return false
        }
        self.contextGesture.activated = { [weak self] gesture, _ in
            guard let self, let itemId = self.itemWithActiveContextGesture,
                  let itemView = self.itemViews[itemId],
                  let item = self.items.first(where: { $0.id == itemId }) else { return }
            self.tabSelectionRecognizer.state = .cancelled
            self.presentContextMenu(item: item, sourceView: itemView, gesture: gesture)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(cancelInteraction), name: UIApplication.willResignActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }

    func update(items: [TelegramTabBarItem], selectedId: AnyHashable, reduceMotion: Bool) {
        let changedSelection = self.selectedId != selectedId
        self.items = items
        self.selectedId = selectedId
        self.reduceMotion = reduceMotion
        if changedSelection { self.overrideSelectedItemId = nil }
        self.updateLayout(transition: changedSelection && !reduceMotion ? .spring(duration: 0.4) : .immediate)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.updateLayout(transition: .immediate)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { self.cancelInteraction() }
    }

    @objc private func cancelInteraction() {
        self.contextGesture.cancel()
        self.tabSelectionRecognizer.state = .cancelled
        self.selectionGestureState = nil
        self.menu?.dismiss(animated: false)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    // The single-tap/drag path from TabBarComponent.onTabSelectionGesture.
    // Telegram's optional double-tap item action is unused by our destinations.
    @objc private func onTabSelectionGesture(_ recognizer: TabSelectionRecognizer) {
        switch recognizer.state {
        case .began:
            if let itemId = self.item(at: recognizer.location(in: self)), let itemView = self.itemViews[itemId] {
                let startX = itemView.frame.minX - 4.0
                self.selectionGestureState = (startX, startX, itemView.bounds.width, itemId)
                self.updateLayout(transition: self.reduceMotion ? .immediate : .spring(duration: 0.4))
            }
        case .changed:
            if var selectionGestureState = self.selectionGestureState {
                selectionGestureState.currentX = selectionGestureState.startX + recognizer.translation(in: self).x
                if let itemId = self.item(at: recognizer.location(in: self)) {
                    selectionGestureState.itemId = itemId
                }
                self.selectionGestureState = selectionGestureState
                self.updateLayout(transition: .immediate)
            }
        case .ended, .cancelled:
            if let selectionGestureState = self.selectionGestureState {
                self.selectionGestureState = nil
                if case .ended = recognizer.state {
                    self.overrideSelectedItemId = selectionGestureState.itemId
                    self.selectionChanged?(selectionGestureState.itemId)
                }
                self.updateLayout(transition: self.reduceMotion ? .immediate : .spring(duration: 0.4))
            }
        default:
            break
        }
    }

    private func item(at point: CGPoint) -> AnyHashable? {
        var closestItem: (AnyHashable, CGFloat)?
        for (id, itemView) in self.itemViews {
            if itemView.frame.contains(point) {
                return id
            } else {
                let distance = abs(point.x - itemView.center.x)
                if let closestItemValue = closestItem {
                    if closestItemValue.1 > distance { closestItem = (id, distance) }
                } else {
                    closestItem = (id, distance)
                }
            }
        }
        return closestItem?.0
    }

    private func presentContextMenu(item: TelegramTabBarItem, sourceView: UIView, gesture: ContextGesture? = nil) {
        guard let window else { return }
        self.menu?.dismiss(animated: false)
        let menu = TelegramContextMenu(sourceView: sourceView, actions: item.contextActions)
        self.menu = menu
        menu.onDismiss = { [weak self, weak menu] in
            if self?.menu === menu { self?.menu = nil }
        }
        // ContextController takes over these callbacks after activation in Telegram.
        gesture?.externalUpdated = { [weak menu] source, point in
            guard let menu else { return }
            menu.updateGesture(location: source?.convert(point, to: window) ?? point)
        }
        gesture?.externalEnded = { [weak menu] value in
            guard let menu else { return }
            guard let (source, point) = value else { menu.dismiss(); return }
            menu.endGesture(location: source?.convert(point, to: window) ?? point)
        }
        menu.present(in: window)
    }

    // TabBarComponent's equal item layout and native lens geometry.
    private func updateLayout(transition: ComponentTransition) {
        guard !items.isEmpty, bounds.width > 0 else { return }
        let innerInset: CGFloat = 4.0
        let availableSize = CGSize(width: min(500.0, bounds.width), height: bounds.height)
        let availableItemsWidth: CGFloat = availableSize.width - innerInset * 2.0
        let isDark = traitCollection.userInterfaceStyle == .dark
        let scale = traitCollection.displayScale
        let equalWidth = floor(availableItemsWidth / CGFloat(items.count) * scale) / scale
        let itemWidths = Array(repeating: equalWidth, count: items.count)
        let totalItemsWidth = equalWidth * CGFloat(items.count)
        let itemHeight: CGFloat = 56.0
        let contentWidth: CGFloat = innerInset * 2.0 + totalItemsWidth
        let tabsSize = CGSize(width: min(availableSize.width, contentWidth), height: itemHeight + innerInset * 2.0)
        var selectionFrame: CGRect?
        var nextItemX: CGFloat = innerInset
        for index in 0 ..< items.count {
            let item = items[index]
            let itemSize = CGSize(width: itemWidths[index], height: itemHeight)
            let itemView: TelegramTabBarItemView
            let selectedItemView: TelegramTabBarItemView
            if let current = itemViews[item.id], let currentSelected = selectedItemViews[item.id] {
                itemView = current
                selectedItemView = currentSelected
            } else {
                itemView = TelegramTabBarItemView()
                selectedItemView = TelegramTabBarItemView()
                itemViews[item.id] = itemView
                selectedItemViews[item.id] = selectedItemView
                itemView.isUserInteractionEnabled = false
                selectedItemView.isUserInteractionEnabled = false
                selectedItemView.accessibilityElementsHidden = true
                self.liquidLensView.contentView.addSubview(itemView)
                self.liquidLensView.selectedContentView.addSubview(selectedItemView)
            }
            let isItemSelected = (overrideSelectedItemId ?? selectedId) == item.id
            itemView.update(item: item, selected: false, isDark: isDark)
            selectedItemView.update(item: item, selected: true, isDark: isDark)
            itemView.accessibilityTraits = isItemSelected ? [.button, .selected] : .button
            itemView.activate = { [weak self] in self?.selectionChanged?(item.id) }
            if !item.contextActions.isEmpty {
                itemView.accessibilityCustomActions?.insert(
                    UIAccessibilityCustomAction(name: String(localized: "Show menu", table: "App")) { [weak self, weak itemView] _ in
                        guard let self, let itemView else { return false }
                        self.presentContextMenu(item: item, sourceView: itemView)
                        return true
                    }, at: 0
                )
            }
            let itemFrame = CGRect(origin: CGPoint(x: nextItemX, y: floor((tabsSize.height - itemSize.height) * 0.5)), size: itemSize)
            nextItemX += itemSize.width
            if isItemSelected {
                if itemFrame.size.width < itemFrame.size.height {
                    selectionFrame = itemFrame.insetBy(dx: floor((itemFrame.size.height * 1.2 - itemFrame.size.width) * -0.5), dy: 0.0)
                } else {
                    selectionFrame = itemFrame
                }
            }
            transition.setFrame(view: itemView, frame: itemFrame)
            transition.setPosition(view: selectedItemView, position: CGPoint(x: itemFrame.midX, y: itemFrame.midY))
            transition.setBounds(view: selectedItemView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
            transition.setScale(view: selectedItemView, scale: (self.selectionGestureState != nil && !reduceMotion) ? 1.15 : 1.0)
        }
        let validIds = Set(items.map(\.id))
        for id in itemViews.keys.filter({ !validIds.contains($0) }) {
            itemViews.removeValue(forKey: id)?.removeFromSuperview()
            selectedItemViews.removeValue(forKey: id)?.removeFromSuperview()
        }
        accessibilityElements = items.compactMap { itemViews[$0.id] }
        transition.setFrame(view: contextGestureContainerView, frame: CGRect(origin: .zero, size: tabsSize))
        transition.setFrame(view: liquidLensView, frame: CGRect(origin: .zero, size: tabsSize))
        var lensSelection: (x: CGFloat, width: CGFloat)
        if let selectionGestureState {
            lensSelection = (selectionGestureState.currentX, selectionGestureState.itemWidth + innerInset * 2.0)
        } else if let selectionFrame {
            lensSelection = (selectionFrame.minX - innerInset, selectionFrame.width + innerInset * 2.0)
        } else {
            lensSelection = (0.0, 56.0)
        }
        lensSelection.x = max(0.0, min(lensSelection.x, tabsSize.width - lensSelection.width))
        self.liquidLensView.update(size: tabsSize, selectionOrigin: CGPoint(x: lensSelection.x, y: 0.0), selectionSize: CGSize(width: lensSelection.width, height: tabsSize.height), inset: 4.0, isDark: isDark, isLifted: self.selectionGestureState != nil && !reduceMotion, isCollapsed: false, transition: transition.withUserData(LiquidLensView.TransitionInfo(disableAnimationWorkarounds: reduceMotion)))
        transition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: .zero, size: tabsSize))
        self.backgroundContainer.update(size: tabsSize, isDark: isDark, transition: transition)
    }
}

// ItemComponent's static-image branch, adapted to centered icons without titles.
private final class TelegramTabBarItemView: UIView {
    private let imageView = UIImageView()
    var activate: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(imageView)
        self.isAccessibilityElement = true
        imageView.contentMode = .center
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: TelegramTabBarItem, selected: Bool, isDark: Bool) {
        imageView.image = selected ? item.selectedImage : item.image
        imageView.tintColor = selected ? .systemBlue : (isDark ? UIColor(white: 0.6, alpha: 1) : UIColor(white: 0, alpha: 0.8))
        accessibilityLabel = item.title
        accessibilityIdentifier = "navigation.\(item.id)"
        accessibilityCustomActions = item.contextActions.map { action in
            UIAccessibilityCustomAction(name: action.title) { _ in action.action(); return true }
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let iconSize = imageView.image?.size ?? CGSize(width: 28, height: 28)
        imageView.frame = CGRect(
            origin: CGPoint(x: floor((bounds.width - iconSize.width) * 0.5), y: floor((bounds.height - iconSize.height) * 0.5)),
            size: iconSize
        )
    }

    override func accessibilityActivate() -> Bool { activate?(); return true }
}
