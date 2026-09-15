// Telegram-iOS source port. Copyright (c) Telegram Messenger.
// SPDX-License-Identifier: GPL-2.0-or-later
// Upstream: https://github.com/TelegramMessenger/Telegram-iOS/blob/6ad963e5b62d354da79040f388ae2b9132fb17b8/submodules/TelegramUI/Components/GlassBackgroundComponent/Sources/GlassBackgroundComponent.swift
// Adaptation: Native iOS 26 GlassBackgroundView and container extracted; legacy raster/mesh glass, component wrappers, and unused tint-mask subclasses omitted. Native effect, tint, luma, clipping, and hit-testing paths retained.

import UIKit
import ObjectiveC.runtime

// Swift translation of UIKitRuntimeUtils/UIViewController+Navigation.m,
// findTopmostEffectSuperview and registerEffectViewOverrides (lines 351–407).
// Install on first use instead of the original Objective-C category's +load.
public final class EffectSettingsContainerView: UIView {
    public var lumaMin: Double = 0.0
    public var lumaMax: Double = 0.0

    private static let registerEffectViewOverrides: Void = {
        let name = "_TtC5UIKitP33_ACD4A08F4BE9D00246F2A9C24A80CA8817UISDFBackdropView"
        let selector = NSSelectorFromString("backdropLayer:didChangeLuma:")
        guard let classValue = NSClassFromString(name),
              let method = class_getInstanceMethod(classValue, selector),
              let encoding = method_getTypeEncoding(method),
              String(cString: encoding) == "v32@0:8@16d24" else {
            return
        }
        typealias Original = @convention(c) (UIView, Selector, CALayer, Double) -> Void
        nonisolated(unsafe) let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
        let replacement: @convention(block) (UIView, CALayer, Double) -> Void = { view, layer, luma in
            // This is UIKit's synchronous main-thread backdrop callback. CALayer
            // and its C implementation pointer lack Swift actor annotations.
            nonisolated(unsafe) let callbackLayer = layer
            MainActor.assumeIsolated {
                var adjustedLuma = luma
                var ancestor: UIView? = view
                for _ in 0...10 {
                    guard let current = ancestor else { break }
                    if let settings = current as? EffectSettingsContainerView {
                        adjustedLuma = min(max(luma, settings.lumaMin), settings.lumaMax)
                        break
                    }
                    ancestor = current.superview
                }
                original(view, selector, callbackLayer, adjustedLuma)
            }
        }
        method_setImplementation(method, imp_implementationWithBlock(replacement))
    }()

    public override init(frame: CGRect) {
        _ = Self.registerEffectViewOverrides
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class GlassBackgroundView: UIView {
    public struct TintColor: Equatable {
        public enum CustomStyle {
            case `default`
            case clear
        }
        
        public enum Kind: Equatable {
            case panel
            case clear
            case custom(style: CustomStyle, color: UIColor)
        }
        
        public let kind: Kind
        public let innerColor: UIColor?
        public let innerInset: CGFloat
        
        public init(kind: Kind, innerColor: UIColor? = nil, innerInset: CGFloat = 3.0) {
            self.kind = kind
            self.innerColor = innerColor
            self.innerInset = innerInset
        }
    }

    public struct CornerRadii: Equatable {
        public let topLeft: CGFloat
        public let topRight: CGFloat
        public let bottomLeft: CGFloat
        public let bottomRight: CGFloat

        public init(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
            self.topLeft = topLeft
            self.topRight = topRight
            self.bottomLeft = bottomLeft
            self.bottomRight = bottomRight
        }

        public init(radius: CGFloat) {
            self.init(topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius)
        }

        fileprivate func insetBy(_ value: CGFloat) -> CornerRadii {
            return CornerRadii(
                topLeft: max(0.0, self.topLeft - value),
                topRight: max(0.0, self.topRight - value),
                bottomLeft: max(0.0, self.bottomLeft - value),
                bottomRight: max(0.0, self.bottomRight - value)
            )
        }

        fileprivate var maximum: CGFloat {
            return max(max(self.topLeft, self.topRight), max(self.bottomLeft, self.bottomRight))
        }
    }

    public enum Shape: Equatable {
        case roundedRect(cornerRadius: CGFloat)
        case customRoundedRect(cornerRadii: CornerRadii)

        fileprivate func cornerRadii(for size: CGSize) -> CornerRadii {
            switch self {
            case let .roundedRect(cornerRadius):
                return GlassBackgroundView.clampedCornerRadii(size: size, cornerRadii: CornerRadii(radius: cornerRadius))
            case let .customRoundedRect(cornerRadii):
                return GlassBackgroundView.clampedCornerRadii(size: size, cornerRadii: cornerRadii)
            }
        }

        func maximumCornerRadius(for size: CGSize) -> CGFloat {
            return self.cornerRadii(for: size).maximum
        }
    }

    static func clampedCornerRadii(size: CGSize, cornerRadii: CornerRadii) -> CornerRadii {
        let size = CGSize(width: max(0.0, size.width), height: max(0.0, size.height))
        var cornerRadii = CornerRadii(
            topLeft: max(0.0, cornerRadii.topLeft),
            topRight: max(0.0, cornerRadii.topRight),
            bottomLeft: max(0.0, cornerRadii.bottomLeft),
            bottomRight: max(0.0, cornerRadii.bottomRight)
        )

        func scaleFor(edgeLength: CGFloat, _ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
            let sum = lhs + rhs
            if sum <= edgeLength || sum.isZero {
                return 1.0
            }
            return edgeLength / sum
        }

        let scale = min(
            1.0,
            scaleFor(edgeLength: size.width, cornerRadii.topLeft, cornerRadii.topRight),
            scaleFor(edgeLength: size.width, cornerRadii.bottomLeft, cornerRadii.bottomRight),
            scaleFor(edgeLength: size.height, cornerRadii.topLeft, cornerRadii.bottomLeft),
            scaleFor(edgeLength: size.height, cornerRadii.topRight, cornerRadii.bottomRight)
        )

        if scale < 1.0 {
            cornerRadii = CornerRadii(
                topLeft: cornerRadii.topLeft * scale,
                topRight: cornerRadii.topRight * scale,
                bottomLeft: cornerRadii.bottomLeft * scale,
                bottomRight: cornerRadii.bottomRight * scale
            )
        }

        return cornerRadii
    }

    static func generateRoundedRectPath(rect: CGRect, cornerRadii: CornerRadii) -> CGPath {
        let cornerRadii = self.clampedCornerRadii(size: rect.size, cornerRadii: cornerRadii)
        let path = CGMutablePath()

        func addCorner(tangent1End: CGPoint, tangent2End: CGPoint, radius: CGFloat) {
            if radius > CGFloat.ulpOfOne {
                path.addArc(tangent1End: tangent1End, tangent2End: tangent2End, radius: radius)
            } else {
                path.addLine(to: tangent1End)
                path.addLine(to: tangent2End)
            }
        }

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadii.topLeft))
        addCorner(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.minX + cornerRadii.topLeft, y: rect.minY),
            radius: cornerRadii.topLeft
        )
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadii.topRight, y: rect.minY))
        addCorner(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY + cornerRadii.topRight),
            radius: cornerRadii.topRight
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadii.bottomRight))
        addCorner(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX - cornerRadii.bottomRight, y: rect.maxY),
            radius: cornerRadii.bottomRight
        )
        path.addLine(to: CGPoint(x: rect.minX + cornerRadii.bottomLeft, y: rect.maxY))
        addCorner(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: rect.maxY - cornerRadii.bottomLeft),
            radius: cornerRadii.bottomLeft
        )
        path.closeSubpath()

        return path
    }

    static func generateRoundedRectPath(size: CGSize, cornerRadii: CornerRadii) -> CGPath {
        return self.generateRoundedRectPath(rect: CGRect(origin: CGPoint(), size: size), cornerRadii: cornerRadii)
    }

    private final class ClippingShapeContext {
        let view: UIView
        private var maskLayer: CAShapeLayer?
        
        private(set) var shape: Shape?
        
        init(view: UIView) {
            self.view = view
        }
        
        func update(shape: Shape, size: CGSize, transition: ComponentTransition) {
            self.shape = shape
            
            switch shape {
            case let .roundedRect(cornerRadius):
                self.maskLayer = nil
                self.view.layer.mask = nil
                transition.setCornerRadius(layer: self.view.layer, cornerRadius: cornerRadius)
            case let .customRoundedRect(cornerRadii):
                transition.setCornerRadius(layer: self.view.layer, cornerRadius: 0.0)
                if #available(iOS 26.0, *) {
                    transition.animateView {
                        self.view.cornerConfiguration = .corners(
                            topLeftRadius: .fixed(cornerRadii.topLeft),
                            topRightRadius: .fixed(cornerRadii.topRight),
                            bottomLeftRadius: .fixed(cornerRadii.bottomLeft),
                            bottomRightRadius: .fixed(cornerRadii.bottomRight)
                        )
                    }

                }
            }
        }
    }

    public struct Params: Equatable {
        public let shape: Shape
        public let isDark: Bool
        public let tintColor: TintColor
        public let isInteractive: Bool
        public let isVisible: Bool
        
        init(shape: Shape, isDark: Bool, tintColor: TintColor, isInteractive: Bool, isVisible: Bool) {
            self.shape = shape
            self.isDark = isDark
            self.tintColor = tintColor
            self.isInteractive = isInteractive
            self.isVisible = isVisible
        }
    }

    private let nativeView: UIVisualEffectView
    private let nativeViewClippingContext: ClippingShapeContext
    private let nativeParamsView: EffectSettingsContainerView
    private var innerBackgroundView: UIView?
    public private(set) var params: Params?

    public var contentView: UIView { self.nativeView.contentView }

    public override init(frame: CGRect) {
        let glassEffect = UIGlassEffect(style: .regular)
        glassEffect.isInteractive = false
        let nativeView = UIVisualEffectView(effect: glassEffect)
        self.nativeViewClippingContext = ClippingShapeContext(view: nativeView)
        self.nativeView = nativeView
        let nativeParamsView = EffectSettingsContainerView(frame: CGRect())
        self.nativeParamsView = nativeParamsView
        nativeParamsView.addSubview(nativeView)
        super.init(frame: frame)
        self.addSubview(nativeParamsView)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.isUserInteractionEnabled || self.isHidden || self.alpha == 0.0 {
            return nil
        }
        return self.nativeView.hitTest(self.convert(point, to: self.nativeView), with: event)
    }

    public func update(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tintColor: TintColor, isInteractive: Bool = false, isVisible: Bool = true, transition: ComponentTransition) {
        let shape: Shape = .roundedRect(cornerRadius: cornerRadius)
        self.update(size: size, shape: shape, isDark: isDark, tintColor: tintColor, isInteractive: isInteractive, isVisible: isVisible, transition: transition)
    }

    public func update(size: CGSize, cornerRadii: CornerRadii, isDark: Bool, tintColor: TintColor, isInteractive: Bool = false, isVisible: Bool = true, transition: ComponentTransition) {
        let shape: Shape = .customRoundedRect(cornerRadii: cornerRadii)
        self.update(size: size, shape: shape, isDark: isDark, tintColor: tintColor, isInteractive: isInteractive, isVisible: isVisible, transition: transition)
    }

    func update(size: CGSize, shape: Shape, isDark: Bool, tintColor: TintColor, isInteractive: Bool = false, isVisible: Bool = true, transition: ComponentTransition) {
        let nativeView = self.nativeView
        let nativeViewClippingContext = self.nativeViewClippingContext
        if (nativeView.bounds.size != size || nativeViewClippingContext.shape != shape || (nativeView.overrideUserInterfaceStyle == .dark) != isDark) {
            nativeViewClippingContext.update(shape: shape, size: size, transition: transition)
            if transition.animation.isImmediate {
                nativeView.frame = CGRect(origin: CGPoint(), size: size)
            } else {
                let nativeFrame = CGRect(origin: CGPoint(), size: size)
                transition.animateView {
                    nativeView.frame = nativeFrame
                }
            }
            nativeView.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
        if let innerColor = tintColor.innerColor {
            let innerBackgroundFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: tintColor.innerInset, dy: tintColor.innerInset)
            let innerBackgroundRadius = min(innerBackgroundFrame.width, innerBackgroundFrame.height) * 0.5
            
            let innerBackgroundView: UIView
            var innerBackgroundTransition = transition
            var animateIn = false
            if let current = self.innerBackgroundView {
                innerBackgroundView = current
            } else {
                innerBackgroundView = UIView()
                innerBackgroundTransition = innerBackgroundTransition.withAnimation(.none)
                self.innerBackgroundView = innerBackgroundView
                self.contentView.insertSubview(innerBackgroundView, at: 0)
                
                innerBackgroundView.frame = innerBackgroundFrame
                innerBackgroundView.layer.cornerRadius = innerBackgroundRadius
                animateIn = true
            }
            
            innerBackgroundView.backgroundColor = innerColor
            innerBackgroundTransition.setFrame(view: innerBackgroundView, frame: innerBackgroundFrame)
            innerBackgroundTransition.setCornerRadius(layer: innerBackgroundView.layer, cornerRadius: innerBackgroundRadius)
            
            if animateIn {
                transition.animateAlpha(view: innerBackgroundView, from: 0.0, to: 1.0)
                transition.animateScale(view: innerBackgroundView, from: 0.001, to: 1.0)
            }
        } else if let innerBackgroundView = self.innerBackgroundView {
            self.innerBackgroundView = nil
            
            transition.setAlpha(view: innerBackgroundView, alpha: 0.0, completion: { [weak innerBackgroundView] _ in
                innerBackgroundView?.removeFromSuperview()
            })
            transition.setScale(view: innerBackgroundView, scale: 0.001)
            
            innerBackgroundView.removeFromSuperview()
        }
        
        let params = Params(shape: shape, isDark: isDark, tintColor: tintColor, isInteractive: isInteractive, isVisible: isVisible)
        if self.params != params {
            self.params = params
            let nativeParamsView = self.nativeParamsView
            var glassEffect: UIGlassEffect?
            
            if isVisible {
                let glassEffectValue: UIGlassEffect
                switch tintColor.kind {
                case .panel:
                    if isDark {
                        glassEffectValue = UIGlassEffect(style: .regular)
                        glassEffectValue.tintColor = UIColor(white: 1.0, alpha: 0.025)
                    } else {
                        glassEffectValue = UIGlassEffect(style: .regular)
                        glassEffectValue.tintColor = UIColor(white: 1.0, alpha: 0.1)
                    }
                case let .custom(style, color):
                    switch style {
                    case .default:
                        glassEffectValue = UIGlassEffect(style: .regular)
                        glassEffectValue.tintColor = color
                    case .clear:
                        glassEffectValue = UIGlassEffect(style: .clear)
                        glassEffectValue.tintColor = color
                    }
                case .clear:
                    glassEffectValue = UIGlassEffect(style: .clear)
                    if isDark {
                        glassEffectValue.tintColor = UIColor(white: 0.0, alpha: 0.28)
                    } else {
                        glassEffectValue.tintColor = nil
                    }
                }
                glassEffectValue.isInteractive = isInteractive
                glassEffect = glassEffectValue
            }
            
            if glassEffect == nil {
                if nativeView.effect is UIGlassEffect {
                    if #available(iOS 26.1, *) {
                        if transition.animation.isImmediate {
                            nativeView.effect = nil
                        } else {
                            transition.animateView {
                                nativeView.effect = nil
                            }
                        }
                    } else {
                        if transition.animation.isImmediate {
                            nativeView.effect = UIVisualEffect()
                        } else {
                            transition.animateView {
                                nativeView.effect = UIVisualEffect()
                            }
                        }
                    }
                }
            } else {
                if transition.animation.isImmediate {
                    nativeView.effect = glassEffect
                } else {
                    if let glassEffect, let currentEffect = nativeView.effect as? UIGlassEffect, currentEffect.tintColor == glassEffect.tintColor, currentEffect.isInteractive == glassEffect.isInteractive {
                    } else {
                        transition.animateView {
                            nativeView.effect = glassEffect
                        }
                    }
                }
            }
            
            if isDark {
                nativeParamsView.lumaMin = 0.0
                nativeParamsView.lumaMax = 0.15
            } else {
                nativeParamsView.lumaMin = 0.8
                nativeParamsView.lumaMax = 0.801
            }
        }
        transition.setFrame(view: self.nativeParamsView, frame: CGRect(origin: CGPoint(), size: size))
    }
}

public final class GlassBackgroundContainerView: UIView {
    private let nativeParamsView: EffectSettingsContainerView
    private let nativeView: UIVisualEffectView

    public var contentView: UIView { self.nativeView.contentView }

    public init(spacing: CGFloat = 7.0) {
        let effect = UIGlassContainerEffect()
        effect.spacing = spacing
        let nativeView = UIVisualEffectView(effect: effect)
        self.nativeView = nativeView
        let nativeParamsView = EffectSettingsContainerView(frame: CGRect())
        self.nativeParamsView = nativeParamsView
        nativeParamsView.addSubview(nativeView)
        super.init(frame: CGRect())
        self.addSubview(nativeParamsView)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        
        if subview !== self.nativeParamsView {
            assertionFailure()
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.alpha.isZero {
            return nil
        }
        if self.isHidden {
            return nil
        }
        if !self.isUserInteractionEnabled {
            return nil
        }
        for view in self.contentView.subviews.reversed() {
            if let result = view.hitTest(self.convert(point, to: view), with: event), result.isUserInteractionEnabled {
                
                #if DEBUG
                func findMatrix(layer: CALayer) -> AnyObject? {
                    for filter in layer.filters ?? [] {
                        if "\(filter)".contains("vibrantColorMatrix") {
                            return filter as AnyObject
                        }
                    }
                    
                    for sublayer in layer.sublayers ?? [] {
                        if let result = findMatrix(layer: sublayer) {
                            return result
                        }
                    }
                    return nil
                }
                
                /*if let filter = findMatrix(layer: self.layer) as? NSObject {
                    var matrix: [Float32] = .init(repeating: 0, count: 20)
                    let matrixValues = filter.value(forKey: "inputColorMatrix") as! NSValue
                    matrixValues.getValue(&matrix, size: 4 * 20)
                    assert(true)
                }*/
                #endif
                
                return result
            }
        }
        
        guard let result = self.contentView.hitTest(point, with: event) else {
            return nil
        }
        
        if result === self.contentView {
            return nil
        }
        
        return result
    }
    
    public func update(size: CGSize, isDark: Bool, transition: ComponentTransition) {
        let nativeParamsView = self.nativeParamsView
        let nativeView = self.nativeView
            nativeView.overrideUserInterfaceStyle = isDark ? .dark : .light
            
            if isDark {
                nativeParamsView.lumaMin = 0.0
                nativeParamsView.lumaMax = 0.15
            } else {
                nativeParamsView.lumaMin = 0.8
                nativeParamsView.lumaMax = 0.801
            }
            transition.setFrame(view: nativeParamsView, frame: CGRect(origin: CGPoint(), size: size))
            
            transition.animateView {
                nativeView.frame = CGRect(origin: CGPoint(), size: size)
            }
    }
    
    override public func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
    }
}
