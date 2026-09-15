// SPDX-License-Identifier: GPL-2.0-or-later
// Portions copyright Telegram Messenger contributors.
// Source: TelegramMessenger/Telegram-iOS, commit
// 6ad963e5b62d354da79040f388ae2b9132fb17b8.
//
// Ported from ContextControllerActionsStackNode.swift:
// ContextControllerActionsListActionItemNode.update (plain title/icon branch),
// ContextControllerActionsListStackItem.Node layout/highlight methods,
// ItemSelectionRecognizer, LensTransitionContainerEffectViewImpl and
// NavigationContainer.update. Also ported LensTransitionContainerImpl's steady
// view hierarchy/update and ContextControllerExtractedPresentationNode's
// reference-source .top layout, animateIn, and animateOut branches.
//
// Adaptations: ASDisplayNode/text nodes become UIKit views/UILabel; account,
// reactions, rich text, nested action stacks, pre-iOS-26 fallbacks and inactive
// extracted-content morphing are omitted. The upstream reference-source morph
// is explicitly disabled by `if !"".isEmpty` (presentation source, line 962).
// Its active tab-menu animation is the spring scale/position animation below.
// PresentationData colors/font are supplied by UIKit traits and Dynamic Type;
// application routing is injected through TelegramContextMenuAction closures.

import UIKit

struct TelegramContextMenuAction {
    let id: String
    let title: String
    let icon: UIImage?
    let action: () -> Void
}

/// A window overlay for Telegram's keep-in-place, top-aligned reference menu.
/// External gesture locations are expressed in the presenting window.
final class TelegramContextMenu: UIView {
    var onDismiss: (() -> Void)?

    private weak var sourceView: UIView?
    private let actions: [TelegramContextMenuAction]
    private let dismissView = UIView()
    private let navigationContainer = TelegramMenuNavigationContainer()
    private let actionsList: TelegramMenuActionsList
    private var initialContinueGesturePoint: CGPoint?
    private var didMoveFromInitialGesturePoint = false
    private var isDismissing = false
    private var hasPresented = false
    private var didCompleteAnimationIn = false

    init(sourceView: UIView, actions: [TelegramContextMenuAction]) {
        self.sourceView = sourceView
        self.actions = actions
        self.actionsList = TelegramMenuActionsList(actions: actions)
        super.init(frame: .zero)

        self.overrideUserInterfaceStyle = sourceView.traitCollection.userInterfaceStyle
        self.backgroundColor = .clear
        self.accessibilityViewIsModal = true
        self.addSubview(self.dismissView)
        self.addSubview(self.navigationContainer)
        self.navigationContainer.contentsView.addSubview(self.actionsList)
        self.accessibilityElements = self.actionsList.accessibleActions
        self.dismissView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dismissTapped)))
        self.actionsList.performAction = { [weak self] action in
            guard let self, !self.isDismissing else { return }
            self.dismiss(animated: true, completion: action.action)
        }
        self.registerForTraitChanges([UITraitPreferredContentSizeCategory.self, UITraitUserInterfaceStyle.self]) {
            (self: TelegramContextMenu, _: UITraitCollection) in
            self.setNeedsLayout()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(in window: UIWindow) {
        guard !self.hasPresented, !self.actions.isEmpty else { return }
        self.hasPresented = true
        self.frame = window.bounds
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(self)
        self.setNeedsLayout()
        self.layoutIfNeeded()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        self.animateIn()
        UIAccessibility.post(notification: .screenChanged, argument: self.actionsList.firstAccessibleAction)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !self.isDismissing, let sourceView = self.sourceView else { return }

        self.dismissView.frame = self.bounds
        let actionsSize = self.actionsList.update(constrainedSize: self.bounds.size, transition: .immediate)

        // ContextControllerExtractedPresentationNode.update, .reference + .top.
        let contentActionsSpacing: CGFloat = 7.0
        let actionsEdgeInset: CGFloat = 16.0
        let actionsSideInset: CGFloat = 6.0
        var contentRect = sourceView.convert(sourceView.bounds, to: self).insetBy(dx: -2.0, dy: 0.0)
        contentRect.size.width += 5.0
        var actionsFrame = CGRect(
            origin: CGPoint(x: actionsSideInset, y: contentRect.minY - contentActionsSpacing - actionsSize.height),
            size: actionsSize
        )
        if contentRect.midX < self.bounds.width / 2.0 {
            actionsFrame.origin.x = contentRect.minX + actionsSideInset - 4.0
        } else {
            actionsFrame.origin.x = floor(contentRect.midX - actionsFrame.width / 2.0)
        }
        if actionsFrame.maxX > self.bounds.width - actionsEdgeInset {
            actionsFrame.origin.x = self.bounds.width - actionsEdgeInset - actionsFrame.width
        }
        if actionsFrame.minX < actionsEdgeInset {
            actionsFrame.origin.x = actionsEdgeInset
        }

        self.navigationContainer.frame = actionsFrame
        self.navigationContainer.update(size: actionsSize, isDark: self.traitCollection.userInterfaceStyle == .dark)
        self.actionsList.frame = CGRect(origin: .zero, size: actionsSize)
    }

    func updateGesture(location: CGPoint) {
        guard !self.isDismissing else { return }
        let localPoint = self.convert(location, from: self.window)
        let initialPoint: CGPoint
        if let current = self.initialContinueGesturePoint {
            initialPoint = current
        } else {
            initialPoint = localPoint
            self.initialContinueGesturePoint = localPoint
        }
        // ContextControllerNode's ContextGesture.externalUpdated branch.
        if !self.didMoveFromInitialGesturePoint {
            let distance = abs(localPoint.y - initialPoint.y)
            if distance > 4.0 {
                self.didMoveFromInitialGesturePoint = true
            }
        }
        if self.didMoveFromInitialGesturePoint && self.didCompleteAnimationIn {
            self.actionsList.highlightGestureMoved(location: self.convert(localPoint, to: self.actionsList))
        }
    }

    func endGesture(location: CGPoint) {
        guard !self.isDismissing else { return }
        self.updateGesture(location: location)
        if self.didMoveFromInitialGesturePoint {
            self.actionsList.highlightGestureFinished(performAction: true)
        }
    }

    func dismiss(animated: Bool = true) {
        self.dismiss(animated: animated, completion: nil)
    }

    override func accessibilityPerformEscape() -> Bool {
        self.dismiss()
        return true
    }

    @objc private func dismissTapped() {
        self.dismiss()
    }

    private func animateIn() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            self.didCompleteAnimationIn = true
            return
        }
        let actionsContainerNode = self.navigationContainer
        let duration: Double = 0.42
        let springDamping: CGFloat = 104.0
        actionsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.05)
        actionsContainerNode.layer.animateSpring(
            from: 0.01 as NSNumber,
            to: 1.0 as NSNumber,
            keyPath: "transform.scale",
            duration: duration,
            delay: 0.0,
            initialVelocity: 0.0,
            damping: springDamping,
            additive: false,
            completion: { [weak self] _ in self?.didCompleteAnimationIn = true }
        )
        actionsContainerNode.layer.animateSpring(
            from: NSValue(cgPoint: self.actionsPositionDelta()),
            to: NSValue(cgPoint: .zero),
            keyPath: "position",
            duration: duration,
            delay: 0.0,
            initialVelocity: 0.0,
            damping: springDamping,
            additive: true
        )
    }

    private func actionsPositionDelta() -> CGPoint {
        guard let sourceView = self.sourceView else { return .zero }
        var contentRect = sourceView.convert(sourceView.bounds, to: self).insetBy(dx: -2.0, dy: 0.0)
        contentRect.size.width += 5.0
        let actionsFrame = self.navigationContainer.frame
        let actionsVerticalTransitionDirection: CGFloat = contentRect.minY < actionsFrame.minY ? -1.0 : 1.0
        return CGPoint(
            x: contentRect.midX - actionsFrame.midX,
            y: actionsVerticalTransitionDirection * actionsFrame.height / 2.0 - 7.0
        )
    }

    private func dismiss(animated: Bool, completion: (() -> Void)?) {
        guard !self.isDismissing else { return }
        self.isDismissing = true
        self.isUserInteractionEnabled = false
        let finish = { [self] in
            self.removeFromSuperview()
            let onDismiss = self.onDismiss
            self.onDismiss = nil
            onDismiss?()
            UIAccessibility.post(notification: .screenChanged, argument: self.sourceView)
            completion?()
        }
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            finish()
            return
        }
        let actionsContainerNode = self.navigationContainer
        let duration: Double = 0.2
        let timingFunction = CAMediaTimingFunctionName.easeInEaseOut.rawValue
        actionsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
        actionsContainerNode.layer.animate(
            from: 1.0 as NSNumber,
            to: 0.01 as NSNumber,
            keyPath: "transform.scale",
            timingFunction: timingFunction,
            duration: duration,
            delay: 0.0,
            removeOnCompletion: false,
            completion: { _ in finish() }
        )
        actionsContainerNode.layer.animate(
            from: NSValue(cgPoint: .zero),
            to: NSValue(cgPoint: self.actionsPositionDelta()),
            keyPath: "position",
            timingFunction: timingFunction,
            duration: duration,
            delay: 0.0,
            removeOnCompletion: false,
            additive: true
        )
    }
}

private final class TelegramMenuActionView: UIButton {
    let item: TelegramContextMenuAction
    private let titleLabelView = UILabel()
    private let iconView = UIImageView()
    var performAction: (() -> Void)?

    init(item: TelegramContextMenuAction) {
        self.item = item
        super.init(frame: .zero)
        self.isAccessibilityElement = true
        self.accessibilityLabel = item.title
        self.accessibilityIdentifier = "telegram-menu-action-\(item.id)"
        self.accessibilityTraits = [.button]
        self.isExclusiveTouch = true
        self.titleLabelView.isAccessibilityElement = false
        self.titleLabelView.isUserInteractionEnabled = false
        self.titleLabelView.numberOfLines = 1
        self.iconView.isAccessibilityElement = false
        self.iconView.isUserInteractionEnabled = false
        self.iconView.contentMode = .scaleAspectFit
        self.addSubview(self.titleLabelView)
        self.addSubview(self.iconView)
        self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func pressed() {
        self.performAction?()
    }

    // Plain text, regular font, single-line icon branch of the upstream update.
    func update(constrainedSize: CGSize) -> (minSize: CGSize, apply: (CGSize, ComponentTransition) -> Void) {
        let sideInset: CGFloat = 18.0
        let verticalInset: CGFloat = 11.0
        let iconSideInset: CGFloat = 20.0
        let standardIconWidth: CGFloat = 32.0
        let iconSpacing: CGFloat = 8.0

        self.titleLabelView.font = UIFont.preferredFont(forTextStyle: .body)
        self.titleLabelView.textColor = .label
        self.titleLabelView.text = self.item.title
        self.iconView.tintColor = .label
        self.iconView.image = self.item.icon
        let iconSize = self.item.icon?.size

        var maxTextWidth = constrainedSize.width
        maxTextWidth -= sideInset
        if let iconSize {
            maxTextWidth -= max(standardIconWidth, iconSize.width)
            maxTextWidth -= iconSpacing
        } else {
            maxTextWidth -= sideInset
        }
        maxTextWidth = max(1.0, maxTextWidth)
        let measuredTitleSize = self.titleLabelView.sizeThatFits(CGSize(width: maxTextWidth, height: 1000.0))
        let titleSize = CGSize(width: min(maxTextWidth, ceil(measuredTitleSize.width)), height: ceil(measuredTitleSize.height))

        var minSize = CGSize()
        minSize.width += sideInset
        minSize.width += titleSize.width
        if let iconSize {
            minSize.width += max(standardIconWidth, iconSize.width)
            minSize.width += iconSideInset
            minSize.width += iconSpacing
        } else {
            minSize.width += sideInset
        }
        minSize.height += verticalInset * 2.0
        minSize.height += titleSize.height

        return (minSize, { [self] size, transition in
            var titleFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalInset), size: titleSize)
            if iconSize != nil {
                titleFrame.origin.x = iconSideInset + 40.0
            }
            transition.setFrame(view: self.titleLabelView, frame: titleFrame)
            if let iconSize {
                let iconFrame = CGRect(
                    origin: CGPoint(
                        x: iconSideInset + floor((standardIconWidth - iconSize.width) * 0.5),
                        y: floor((size.height - iconSize.height) / 2.0)
                    ),
                    size: iconSize
                )
                transition.setFrame(view: self.iconView, frame: iconFrame)
            }
        })
    }
}

private final class TelegramMenuActionsList: UIView {
    var accessibleActions: [UIView] { self.itemViews }
    var performAction: ((TelegramContextMenuAction) -> Void)?
    var firstAccessibleAction: UIView? { self.itemViews.first }

    private let highlightedItemBackgroundView = UIView()
    private let itemViews: [TelegramMenuActionView]
    private var highlightedItemView: TelegramMenuActionView?
    private var constrainedSize: CGSize = .zero
    private let hapticFeedback = UISelectionFeedbackGenerator()

    init(actions: [TelegramContextMenuAction]) {
        self.itemViews = actions.map(TelegramMenuActionView.init)
        super.init(frame: .zero)
        self.highlightedItemBackgroundView.alpha = 0.0
        self.addSubview(self.highlightedItemBackgroundView)
        for itemView in self.itemViews {
            self.addSubview(itemView)
            itemView.performAction = { [weak self, weak itemView] in
                if let itemView { self?.performAction?(itemView.item) }
            }
        }
        let selectionPanGesture = TelegramMenuItemSelectionRecognizer(target: self, action: #selector(self.panGesture(_:)))
        selectionPanGesture.shouldBegin = { [weak self] point in
            self?.bounds.contains(point) == true
        }
        self.addGestureRecognizer(selectionPanGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    func update(constrainedSize: CGSize, transition: ComponentTransition) -> CGSize {
        self.constrainedSize = constrainedSize
        let verticalInset: CGFloat = 10.0
        let standardMinWidth: CGFloat = 220.0
        let standardMaxWidth: CGFloat = 240.0
        var itemLayouts: [(minSize: CGSize, apply: (CGSize, ComponentTransition) -> Void)] = []
        var combinedSize = CGSize.zero
        for i in 0 ..< self.itemViews.count {
            let item = self.itemViews[i]
            let itemLayout = item.update(constrainedSize: CGSize(width: standardMaxWidth, height: constrainedSize.height))
            if i == 0 { combinedSize.height += verticalInset }
            itemLayouts.append(itemLayout)
            combinedSize.width = max(combinedSize.width, itemLayout.minSize.width)
            combinedSize.height += itemLayout.minSize.height
            if i == self.itemViews.count - 1 { combinedSize.height += verticalInset }
        }
        combinedSize.width = max(combinedSize.width, standardMinWidth)

        var nextItemOrigin = CGPoint.zero
        var highlightedItemFrame: CGRect?
        for i in 0 ..< self.itemViews.count {
            let item = self.itemViews[i]
            let itemLayout = itemLayouts[i]
            let itemTransition: ComponentTransition = item.frame.isEmpty ? .immediate : transition
            if i == 0 { nextItemOrigin.y += verticalInset }
            let itemSize = CGSize(width: combinedSize.width, height: itemLayout.minSize.height)
            let itemFrame = CGRect(origin: nextItemOrigin, size: itemSize)
            itemTransition.setFrame(view: item, frame: itemFrame)
            itemLayout.apply(itemSize, itemTransition)
            nextItemOrigin.y += itemSize.height
            if self.highlightedItemView === item { highlightedItemFrame = itemFrame }
        }

        if let highlightedItemFrame {
            self.highlightedItemBackgroundView.backgroundColor = self.traitCollection.userInterfaceStyle == .dark ? .white : .black
            self.highlightedItemBackgroundView.setMonochromaticEffect(tintColor: self.highlightedItemBackgroundView.backgroundColor)
            var highlightTransition = transition
            var animateIn = false
            if self.highlightedItemBackgroundView.alpha == 0.0 {
                if self.highlightedItemBackgroundView.layer.animation(forKey: "opacity") == nil {
                    highlightTransition = .immediate
                }
                animateIn = true
            }
            let highlightFrame = CGRect(origin: CGPoint(x: 10.0, y: highlightedItemFrame.minY), size: CGSize(width: combinedSize.width - 10.0 * 2.0, height: highlightedItemFrame.height))
            highlightTransition.setFrame(view: self.highlightedItemBackgroundView, frame: highlightFrame)
            highlightTransition.setCornerRadius(layer: self.highlightedItemBackgroundView.layer, cornerRadius: min(20.0, highlightFrame.height * 0.5))
            if animateIn {
                ComponentTransition.easeInOut(duration: 0.2).setAlpha(view: self.highlightedItemBackgroundView, alpha: 0.1)
            }
        } else if self.highlightedItemBackgroundView.alpha != 0.0 {
            transition.setAlpha(view: self.highlightedItemBackgroundView, alpha: 0.0)
        }
        return combinedSize
    }

    func highlightGestureMoved(location: CGPoint) {
        var highlightedItemView: TelegramMenuActionView?
        for itemView in self.itemViews {
            if itemView.frame.contains(location) {
                highlightedItemView = itemView
                break
            }
        }
        if self.highlightedItemView !== highlightedItemView {
            self.highlightedItemView = highlightedItemView
            self.hapticFeedback.selectionChanged()
            self.update(constrainedSize: self.constrainedSize, transition: .easeInOut(duration: 0.16))
        }
    }

    func highlightGestureFinished(performAction: Bool) {
        if let highlightedItemView = self.highlightedItemView {
            self.highlightedItemView = nil
            if performAction { self.performAction?(highlightedItemView.item) }
            self.update(constrainedSize: self.constrainedSize, transition: .easeInOut(duration: 0.2))
        }
    }

    @objc private func panGesture(_ recognizer: TelegramMenuItemSelectionRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            self.highlightGestureMoved(location: recognizer.location(in: self))
        case .ended:
            self.highlightGestureFinished(performAction: true)
        case .cancelled:
            self.highlightGestureFinished(performAction: false)
        default:
            break
        }
    }
}

// ItemSelectionRecognizer from ContextControllerActionsStackNode.swift.
private final class TelegramMenuItemSelectionRecognizer: UIGestureRecognizer {
    var shouldBegin: ((CGPoint) -> Bool)?
    private var initialLocation: CGPoint?
    private var currentLocation: CGPoint?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
    }

    override func reset() {
        super.reset()
        self.initialLocation = nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if let location = touches.first?.location(in: self.view), let shouldBegin = self.shouldBegin, !shouldBegin(location) {
            self.state = .failed
            return
        }
        if self.initialLocation == nil {
            self.initialLocation = touches.first?.location(in: self.view)
        }
        self.currentLocation = self.initialLocation
        self.state = .began
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        self.state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        self.state = .cancelled
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        self.currentLocation = touches.first?.location(in: self.view)
        self.state = .changed
    }
}

private final class TelegramMenuNavigationContainer: UIView {
    private let backgroundContainer = GlassBackgroundContainerView(spacing: 28.0)
    private let contentContainer = TelegramMenuLensContainer()
    var contentsView: UIView { self.contentContainer.contentsView }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.backgroundContainer)
        self.backgroundContainer.contentView.addSubview(self.contentContainer)
    }

    convenience init() { self.init(frame: .zero) }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize, isDark: Bool) {
        let transition = ComponentTransition.immediate
        transition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: .zero, size: size))
        self.backgroundContainer.update(size: size, isDark: isDark, transition: transition)
        transition.setPosition(view: self.contentContainer, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
        transition.setBounds(view: self.contentContainer, bounds: CGRect(origin: .zero, size: size))
        self.contentContainer.update(size: size, cornerRadius: min(30.0, size.height * 0.5), transition: transition)
    }
}

/// Reachable steady rendering of LensTransitionContainerImpl for reference tabs.
private final class TelegramMenuLensContainer: UIView {
    private let effectSettingsContainerView = EffectSettingsContainerView()
    private let containerView = UIView()
    private let effectView = TelegramMenuLensEffectView()
    private let contentsEffectView = UIView()
    let contentsView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.effectSettingsContainerView)
        self.effectSettingsContainerView.addSubview(self.containerView)
        self.contentsView.clipsToBounds = true
        self.containerView.addSubview(self.effectView)
        self.containerView.addSubview(self.contentsEffectView)
        self.contentsEffectView.addSubview(self.contentsView)
    }

    convenience init() { self.init(frame: .zero) }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize, cornerRadius: CGFloat, transition: ComponentTransition) {
        let bounds = CGRect(origin: .zero, size: size)
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        // UIKit accessibility needs a sized ancestor; Telegram's display-node
        // layer supplies its own accessibility containers around this view.
        transition.setFrame(view: self.effectSettingsContainerView, frame: bounds)
        transition.setBounds(view: self.containerView, bounds: bounds)
        transition.setPosition(view: self.containerView, position: center)
        transition.setBounds(view: self.contentsView, bounds: bounds)
        transition.setPosition(view: self.contentsView, position: center)
        transition.setCornerRadius(layer: self.contentsView.layer, cornerRadius: cornerRadius)
        transition.setBounds(view: self.contentsEffectView, bounds: bounds)
        transition.setPosition(view: self.contentsEffectView, position: center)
        self.effectView.updateSize(size: size, transition: transition)
        self.effectView.updatePosition(position: center, transition: transition)
        self.effectView.updateCornerRadius(cornerRadius)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        self.contentsView.hitTest(point, with: event)
    }
}

/// LensTransitionContainerEffectViewImpl's native glass and steady update path.
private final class TelegramMenuLensEffectView: UIView {
    private let glassView = UIVisualEffectView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.glassView)
        self.glassView.effect = UIGlassEffect(style: .regular)
    }

    convenience init() { self.init(frame: .zero) }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateSize(size: CGSize, transition: ComponentTransition) {
        transition.setBounds(view: self, bounds: CGRect(origin: .zero, size: size))
        transition.setBounds(view: self.glassView, bounds: CGRect(origin: .zero, size: size))
        transition.setPosition(view: self.glassView, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
    }

    func updatePosition(position: CGPoint, transition: ComponentTransition) {
        transition.setPosition(view: self, position: position)
    }

    func updateCornerRadius(_ cornerRadius: CGFloat) {
        self.glassView.cornerConfiguration = .corners(radius: UICornerRadius(floatLiteral: cornerRadius))
    }
}
