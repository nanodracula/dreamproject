// Telegram-iOS source port. Copyright (c) Telegram Messenger.
// SPDX-License-Identifier: GPL-2.0-or-later
// Upstream: https://github.com/TelegramMessenger/Telegram-iOS/blob/6ad963e5b62d354da79040f388ae2b9132fb17b8/submodules/ComponentFlow/Source/Base/Transition.swift
// Adaptation: Selected original transition and CAAnimationUtils methods plus UIKitRuntimeUtils spring constants. UIKit timing providers preserve the selected curve without Telegram's module-wide CALayer animation swizzle; unsupported component-tree APIs are not imported.

import UIKit

@objc private class CALayerAnimationDelegate: NSObject, CAAnimationDelegate {
    private let keyPath: String?
    var completion: ((Bool) -> Void)?
    
    init(animation: CAAnimation, completion: ((Bool) -> Void)?) {
        if let animation = animation as? CABasicAnimation {
            self.keyPath = animation.keyPath
        } else {
            self.keyPath = nil
        }
        self.completion = completion
        
        super.init()
    }
    
    @objc func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if let anim = anim as? CABasicAnimation {
            if anim.keyPath != self.keyPath {
                return
            }
        }
        if let completion = self.completion {
            completion(flag)
            self.completion = nil
        }
    }
}

public let kCAMediaTimingFunctionSpring = "CAAnimationUtilsSpringCurve"
public let kCAMediaTimingFunctionCustomSpringPrefix = "CAAnimationUtilsSpringCustomCurve"

public extension CAAnimation {
    var completion: ((Bool) -> Void)? {
        get {
            if let delegate = self.delegate as? CALayerAnimationDelegate {
                return delegate.completion
            } else {
                return nil
            }
        } set(value) {
            if let delegate = self.delegate as? CALayerAnimationDelegate {
                delegate.completion = value
            } else {
                self.delegate = CALayerAnimationDelegate(animation: self, completion: value)
            }
        }
    }
}

private func adjustFrameRate(animation: CAAnimation) {
    if #available(iOS 15.0, *) {
        let maxFps = Float(UIScreen.main.maximumFramesPerSecond)
        if maxFps > 61.0 {
            var preferredFps: Float = maxFps
            if let animation = animation as? CABasicAnimation {
                if animation.keyPath == "opacity" {
                    preferredFps = 60.0
                    return
                }
            }
            animation.preferredFrameRateRange = CAFrameRateRange(minimum: 30.0, maximum: preferredFps, preferred: maxFps)
        }
    }
}

#if targetEnvironment(simulator)
@_silgen_name("UIAnimationDragCoefficient") private func telegramAnimationDragCoefficient() -> Float
#endif

extension UIView {
    static func animationDurationFactor() -> Double {
        #if targetEnvironment(simulator)
        return Double(telegramAnimationDragCoefficient())
        #else
        return 1.0
        #endif
    }
}

private func make26SpringAnimationImpl(_ keyPath: String, _ duration: Double) -> CASpringAnimation {
    let animation = CASpringAnimation(keyPath: keyPath)
    animation.mass = 1.0
    animation.stiffness = 555.027
    animation.damping = 47.118
    animation.duration = duration
    animation.timingFunction = CAMediaTimingFunction(name: .linear)
    animation.allowsOverdamping = false
    animation.setValue(1048619, forKey: "highFrameRateReason")
    animation.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
    return animation
}

private func makeSpringAnimation(_ keyPath: String, duration: Double) -> CASpringAnimation {
    make26SpringAnimationImpl(keyPath, duration)
}

private func makeSpringBounceAnimation(_ keyPath: String, _ initialVelocity: CGFloat, _ damping: CGFloat) -> CASpringAnimation {
    let animation = CASpringAnimation(keyPath: keyPath)
    animation.mass = 5.0
    animation.stiffness = 900.0
    animation.damping = damping
    animation.initialVelocity = initialVelocity
    animation.duration = animation.settlingDuration
    animation.timingFunction = CAMediaTimingFunction(name: .linear)
    return animation
}

public extension CALayer {
    func makeAnimation(from: Any?, to: Any, keyPath: String, timingFunction: String, duration: Double, delay: Double = 0.0, mediaTimingFunction: CAMediaTimingFunction? = nil, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) -> CAAnimation {
        if timingFunction.hasPrefix(kCAMediaTimingFunctionCustomSpringPrefix) {
            let components = timingFunction.components(separatedBy: "_")
            let mass: Float
            let stiffness: Float
            let damping: Float
            let initialVelocity: Float
            if components.count >= 5 {
                mass = Float(components[1]) ?? 5.0
                stiffness = Float(components[2]) ?? 900.0
                damping = Float(components[3]) ?? 100.0
                initialVelocity = Float(components[4]) ?? 0.0
            } else {
                mass = 5.0
                stiffness = 900.0
                damping = components.count > 1 ? (Float(components[1]) ?? 100.0) : 100.0
                initialVelocity = components.count > 2 ? (Float(components[2]) ?? 0.0) : 0.0
            }
            
            let animation = CASpringAnimation(keyPath: keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.isRemovedOnCompletion = removeOnCompletion
            animation.fillMode = .forwards
            if let completion = completion {
                animation.delegate = CALayerAnimationDelegate(animation: animation, completion: completion)
            }
            animation.mass = CGFloat(mass)
            animation.stiffness = CGFloat(stiffness)
            animation.damping = CGFloat(damping)
            animation.initialVelocity = CGFloat(initialVelocity)
            animation.duration = animation.settlingDuration
            animation.timingFunction = CAMediaTimingFunction.init(name: .linear)
            let k = Float(UIView.animationDurationFactor())
            var speed: Float = 1.0
            if k != 0 && k != 1 {
                speed = Float(1.0) / k
            }
            animation.speed = speed * Float(animation.duration / duration)
            animation.isAdditive = additive
            if !delay.isZero {
                animation.beginTime = self.convertTime(CACurrentMediaTime(), from: nil) + delay * UIView.animationDurationFactor()
                animation.fillMode = .both
            }
            adjustFrameRate(animation: animation)
            
            return animation
        } else if timingFunction == kCAMediaTimingFunctionSpring {
            if #available(iOS 26.0, *), abs(duration - 0.3832) <= 0.0001 {
                let animation = make26SpringAnimationImpl(keyPath, duration)
                animation.fromValue = from
                animation.toValue = to
                animation.isRemovedOnCompletion = removeOnCompletion
                animation.fillMode = .forwards
                if let completion {
                    animation.delegate = CALayerAnimationDelegate(animation: animation, completion: completion)
                }
                
                let k = Float(UIView.animationDurationFactor())
                var speed: Float = 1.0
                if k != 0 && k != 1 {
                    speed = Float(1.0) / k
                }
                
                animation.speed = speed * Float(animation.duration / duration)
                animation.isAdditive = additive
                
                if !delay.isZero {
                    animation.beginTime = self.convertTime(CACurrentMediaTime(), from: nil) + delay * UIView.animationDurationFactor()
                    animation.fillMode = .both
                }
                
                adjustFrameRate(animation: animation)
                
                return animation
            } else if duration == 0.5 {
                let animation = makeSpringAnimation(keyPath, duration: duration)
                animation.fromValue = from
                animation.toValue = to
                animation.isRemovedOnCompletion = removeOnCompletion
                animation.fillMode = .forwards
                if let completion = completion {
                    animation.delegate = CALayerAnimationDelegate(animation: animation, completion: completion)
                }
                
                let k = Float(UIView.animationDurationFactor())
                var speed: Float = 1.0
                if k != 0 && k != 1 {
                    speed = Float(1.0) / k
                }
                
                animation.speed = speed * Float(animation.duration / duration)
                animation.isAdditive = additive
                
                if !delay.isZero {
                    animation.beginTime = self.convertTime(CACurrentMediaTime(), from: nil) + delay * UIView.animationDurationFactor()
                    animation.fillMode = .both
                }
                
                adjustFrameRate(animation: animation)
                
                return animation
            } else {
                let k = Float(UIView.animationDurationFactor())
                var speed: Float = 1.0
                if k != 0 && k != 1 {
                    speed = Float(1.0) / k
                }
                
                let animation = CABasicAnimation(keyPath: keyPath)
                animation.fromValue = from
                animation.toValue = to
                animation.duration = duration
                
                animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.380, 0.700, 0.125, 1.000)
                
                animation.isRemovedOnCompletion = removeOnCompletion
                animation.fillMode = .forwards
                animation.speed = speed
                animation.isAdditive = additive
                if let completion = completion {
                    animation.delegate = CALayerAnimationDelegate(animation: animation, completion: completion)
                }
                
                if !delay.isZero {
                    animation.beginTime = self.convertTime(CACurrentMediaTime(), from: nil) + delay * UIView.animationDurationFactor()
                    animation.fillMode = .both
                }
                
                adjustFrameRate(animation: animation)
                
                return animation
            }
        } else {
            let k = Float(UIView.animationDurationFactor())
            var speed: Float = 1.0
            if k != 0 && k != 1 {
                speed = Float(1.0) / k
            }
            
            let animation = CABasicAnimation(keyPath: keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.duration = duration
            if let mediaTimingFunction = mediaTimingFunction {
                animation.timingFunction = mediaTimingFunction
            } else {
                switch timingFunction {
                case CAMediaTimingFunctionName.linear.rawValue, CAMediaTimingFunctionName.easeIn.rawValue, CAMediaTimingFunctionName.easeOut.rawValue, CAMediaTimingFunctionName.easeInEaseOut.rawValue, CAMediaTimingFunctionName.default.rawValue:
                    animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName(rawValue: timingFunction))
                default:
                    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                }
                
            }
            animation.isRemovedOnCompletion = removeOnCompletion
            animation.fillMode = .forwards
            animation.speed = speed
            animation.isAdditive = additive
            if let completion = completion {
                animation.delegate = CALayerAnimationDelegate(animation: animation, completion: completion)
            }
            
            if !delay.isZero {
                animation.beginTime = self.convertTime(CACurrentMediaTime(), from: nil) + delay * UIView.animationDurationFactor()
                animation.fillMode = .both
            }
            
            adjustFrameRate(animation: animation)
            
            return animation
        }
    }

    func animate(from: Any?, to: Any, keyPath: String, timingFunction: String, duration: Double, delay: Double = 0.0, mediaTimingFunction: CAMediaTimingFunction? = nil, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil, key: String? = nil) {
        let animation = self.makeAnimation(from: from, to: to, keyPath: keyPath, timingFunction: timingFunction, duration: duration, delay: delay, mediaTimingFunction: mediaTimingFunction, removeOnCompletion: removeOnCompletion, additive: additive, completion: completion)
        self.add(animation, forKey: key ?? (additive ? nil : keyPath))
    }

    func animateSpring(from: Any, to: Any, keyPath: String, duration: Double, delay: Double = 0.0, initialVelocity: CGFloat = 0.0, stiffness: CGFloat = 900.0, damping: CGFloat = 88.0, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil, key: String? = nil) {
        let animation = makeSpringBounceAnimation(keyPath, initialVelocity, damping)
        animation.stiffness = stiffness
        animation.fromValue = from
        animation.toValue = to
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(animation: animation, completion: completion)
        }
        
        let k = Float(UIView.animationDurationFactor())
        var speed: Float = 1.0
        if k != 0 && k != 1 {
            speed = Float(1.0) / k
        }
        
        if !delay.isZero {
            animation.beginTime = self.convertTime(CACurrentMediaTime(), from: nil) + delay * UIView.animationDurationFactor()
            animation.fillMode = .both
        }
        
        animation.speed = speed * Float(animation.duration / duration)
        animation.isAdditive = additive
        
        adjustFrameRate(animation: animation)
        
        self.add(animation, forKey: additive ? key : (key ?? keyPath))
    }

    func animateAlpha(from: CGFloat, to: CGFloat, duration: Double, delay: Double = 0.0, timingFunction: String = CAMediaTimingFunctionName.easeInEaseOut.rawValue, mediaTimingFunction: CAMediaTimingFunction? = nil, removeOnCompletion: Bool = true, completion: ((Bool) -> ())? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "opacity", timingFunction: timingFunction, duration: duration, delay: delay, mediaTimingFunction: mediaTimingFunction, removeOnCompletion: removeOnCompletion, completion: completion)
    }

    func animateScale(from: CGFloat, to: CGFloat, duration: Double, delay: Double = 0.0, timingFunction: String = CAMediaTimingFunctionName.easeInEaseOut.rawValue, mediaTimingFunction: CAMediaTimingFunction? = nil, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "transform.scale", timingFunction: timingFunction, duration: duration, delay: delay, mediaTimingFunction: mediaTimingFunction, removeOnCompletion: removeOnCompletion, additive: additive, completion: completion)
    }

    func animatePosition(from: CGPoint, to: CGPoint, duration: Double, delay: Double = 0.0, timingFunction: String = CAMediaTimingFunctionName.easeInEaseOut.rawValue, mediaTimingFunction: CAMediaTimingFunction? = nil, removeOnCompletion: Bool = true, additive: Bool = false, force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if from == to && !force {
            if let completion = completion {
                completion(true)
            }
            return
        }
        self.animate(from: NSValue(cgPoint: from), to: NSValue(cgPoint: to), keyPath: "position", timingFunction: timingFunction, duration: duration, delay: delay, mediaTimingFunction: mediaTimingFunction, removeOnCompletion: removeOnCompletion, additive: additive, completion: completion)
    }

    static func blur() -> NSObject? {
        guard let factory = NSClassFromString("CAFilter") as AnyObject as? NSObjectProtocol else { return nil }
        return factory.perform(NSSelectorFromString("filterWithName:"), with: "gaussianBlur")?.takeUnretainedValue() as? NSObject
    }
}

public extension CALayer {
    func animate(from: Any, to: Any, keyPath: String, duration: Double, delay: Double, curve: ComponentTransition.Animation.Curve, removeOnCompletion: Bool, additive: Bool, completion: ((Bool) -> Void)? = nil, key: String? = nil) {
        if case let .bounce(stiffness, damping) = curve {
            self.animateSpring(
                from: from,
                to: to,
                keyPath: keyPath,
                duration: duration,
                delay: delay,
                stiffness: stiffness,
                damping: damping,
                removeOnCompletion: removeOnCompletion,
                additive: additive,
                completion: completion,
                key: key
            )
        } else {
            let timingFunction: String
            let mediaTimingFunction: CAMediaTimingFunction?
            switch curve {
            case .spring:
                timingFunction = kCAMediaTimingFunctionSpring
                mediaTimingFunction = nil
            default:
                timingFunction = CAMediaTimingFunctionName.easeInEaseOut.rawValue
                mediaTimingFunction = curve.asTimingFunction()
            }
            
            self.animate(
                from: from,
                to: to,
                keyPath: keyPath,
                timingFunction: timingFunction,
                duration: duration,
                delay: delay,
                mediaTimingFunction: mediaTimingFunction,
                removeOnCompletion: removeOnCompletion,
                additive: additive,
                completion: completion,
                key: key
            )
        }
    }
}

private extension ComponentTransition.Animation.Curve {
    func asTimingFunction() -> CAMediaTimingFunction {
        switch self {
        case .easeInOut:
            return CAMediaTimingFunction(name: .easeInEaseOut)
        case .easeIn:
            return CAMediaTimingFunction(name: .easeIn)
        case .linear:
            return CAMediaTimingFunction(name: .linear)
        case let .custom(a, b, c, d):
            return CAMediaTimingFunction(controlPoints: a, b, c, d)
        case .spring, .bounce:
            preconditionFailure()
        }
    }

    var viewAnimationOptions: UIView.AnimationOptions {
        switch self {
        case .linear:
            return [.curveLinear]
        case .easeInOut:
            return [.curveEaseInOut]
        case .easeIn:
            return [.curveEaseIn]
        case .spring:
            return UIView.AnimationOptions(rawValue: 7 << 16)
        case .custom:
            return []
        case .bounce:
            return []
        }
    }
}

public extension ComponentTransition.Animation {
    var isImmediate: Bool {
        if case .none = self {
            return true
        } else {
            return false
        }
    }
}

public struct ComponentTransition {
    public enum Animation {
        public enum Curve {
            case easeInOut, easeIn, spring, linear
            case custom(Float, Float, Float, Float)
            case bounce(stiffness: CGFloat, damping: CGFloat)
            public static var slide: Curve { .custom(0.33, 0.52, 0.25, 0.99) }
        }
        case none
        case curve(duration: Double, curve: Curve)
    }
    public var animation: Animation
    private var _userData: [Any] = []
    public func userData<T>(_ type: T.Type) -> T? {
        for item in self._userData.reversed() {
            if let item = item as? T {
                return item
            }
        }
        return nil
    }

    public func withUserData(_ userData: Any) -> ComponentTransition {
        var result = self
        result._userData.append(userData)
        return result
    }

    public func withAnimation(_ animation: Animation) -> ComponentTransition {
        var result = self
        result.animation = animation
        return result
    }

    public func withAnimationIfAnimated(_ animation: Animation) -> ComponentTransition {
        switch self.animation {
        case .none:
            return self
        default:
            var result = self
            result.animation = animation
            return result
        }
    }

    public static func easeInOut(duration: Double) -> ComponentTransition {
        return ComponentTransition(animation: .curve(duration: duration, curve: .easeInOut))
    }

    public static func spring(duration: Double) -> ComponentTransition {
        return ComponentTransition(animation: .curve(duration: duration, curve: .spring))
    }

    public init(animation: Animation) {
        self.animation = animation
    }

    public static var immediate: ComponentTransition { ComponentTransition(animation: .none) }
    public static func animated(duration: Double, curve: Animation.Curve) -> ComponentTransition {
        ComponentTransition(animation: .curve(duration: duration, curve: curve))
    }
    public func setFrame(view: UIView, frame: CGRect, completion: ((Bool) -> Void)? = nil) {
        if view.frame == frame {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            view.frame = frame
            view.layer.removeAnimation(forKey: "position")
            view.layer.removeAnimation(forKey: "bounds")
            view.layer.removeAnimation(forKey: "bounds.size")
            completion?(true)
        case .curve:
            let previousPosition: CGPoint
            let previousBounds: CGRect
            if (view.layer.animation(forKey: "position") != nil || view.layer.animation(forKey: "bounds") != nil || view.layer.animation(forKey: "bounds.size") != nil), let presentation = view.layer.presentation() {
                previousPosition = presentation.position
                previousBounds = presentation.bounds
            } else {
                previousPosition = view.layer.position
                previousBounds = view.layer.bounds
            }
            
            view.frame = frame
            
            let anchorPoint = view.layer.anchorPoint
            let updatedPosition = CGPoint(x: frame.minX + frame.width * anchorPoint.x, y: frame.minY + frame.height * anchorPoint.y)

            self.animatePosition(view: view, from: previousPosition, to: updatedPosition, completion: completion)
            if previousBounds.size != frame.size {
                self.animateBoundsSize(view: view, from: previousBounds.size, to: frame.size)
            }
        }
    }

    public func setFrame(layer: CALayer, frame: CGRect, completion: ((Bool) -> Void)? = nil) {
        if layer.frame == frame {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            layer.frame = frame
            //view.bounds = CGRect(origin: view.bounds.origin, size: frame.size)
            //view.layer.position = CGPoint(x: frame.midX, y: frame.midY)
            layer.removeAnimation(forKey: "position")
            layer.removeAnimation(forKey: "bounds")
            completion?(true)
        case .curve:
            let previousFrame: CGRect
            if (layer.animation(forKey: "position") != nil || layer.animation(forKey: "bounds") != nil), let presentation = layer.presentation() {
                previousFrame = presentation.frame
            } else {
                previousFrame = layer.frame
            }
            
            layer.frame = frame
            //view.bounds = CGRect(origin: previousBounds.origin, size: frame.size)
            //view.center = CGPoint(x: frame.midX, y: frame.midY)

            self.animatePosition(layer: layer, from: CGPoint(x: previousFrame.midX, y: previousFrame.midY), to: CGPoint(x: frame.midX, y: frame.midY), completion: completion)
            self.animateBounds(layer: layer, from: CGRect(origin: layer.bounds.origin, size: previousFrame.size), to: CGRect(origin: layer.bounds.origin, size: frame.size))
        }
    }

    public func setBounds(view: UIView, bounds: CGRect, completion: ((Bool) -> Void)? = nil) {
        if view.bounds == bounds {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            view.bounds = bounds
            view.layer.removeAnimation(forKey: "bounds")
            view.layer.removeAnimation(forKey: "bounds.origin")
            view.layer.removeAnimation(forKey: "bounds.size")
            completion?(true)
        case .curve:
            let previousBounds: CGRect
            if (view.layer.animation(forKey: "bounds") != nil || view.layer.animation(forKey: "bounds.origin") != nil || view.layer.animation(forKey: "bounds.size") != nil), let presentation = view.layer.presentation() {
                previousBounds = presentation.bounds
            } else {
                previousBounds = view.layer.bounds
            }
            view.bounds = bounds

            self.animateBounds(view: view, from: previousBounds, to: view.bounds, completion: completion)
        }
    }

    public func setBounds(layer: CALayer, bounds: CGRect, completion: ((Bool) -> Void)? = nil) {
        if layer.bounds == bounds {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            layer.bounds = bounds
            layer.removeAnimation(forKey: "bounds")
            completion?(true)
        case .curve:
            let previousBounds: CGRect
            if layer.animation(forKey: "bounds") != nil, let presentation = layer.presentation() {
                previousBounds = presentation.bounds
            } else {
                previousBounds = layer.bounds
            }
            layer.bounds = bounds

            self.animateBounds(layer: layer, from: previousBounds, to: layer.bounds, completion: completion)
        }
    }

    public func setPosition(view: UIView, position: CGPoint, delay: Double = 0.0, completion: ((Bool) -> Void)? = nil) {
        if view.center == position {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            view.center = position
            view.layer.removeAnimation(forKey: "position")
            completion?(true)
        case .curve:
            let previousPosition: CGPoint
            if view.layer.animation(forKey: "position") != nil, let presentation = view.layer.presentation() {
                previousPosition = presentation.position
            } else {
                previousPosition = view.layer.position
            }
            view.center = position

            self.animatePosition(view: view, from: previousPosition, to: view.center, delay: delay, completion: completion)
        }
    }

    public func setPosition(layer: CALayer, position: CGPoint, completion: ((Bool) -> Void)? = nil) {
        if layer.position == position {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            layer.position = position
            layer.removeAnimation(forKey: "position")
            completion?(true)
        case .curve:
            let previousPosition: CGPoint
            if layer.animation(forKey: "position") != nil, let presentation = layer.presentation() {
                previousPosition = presentation.position
            } else {
                previousPosition = layer.position
            }
            layer.position = position

            self.animatePosition(layer: layer, from: previousPosition, to: layer.position, completion: completion)
        }
    }

    public func setAlpha(view: UIView, alpha: CGFloat, delay: Double = 0.0, completion: ((Bool) -> Void)? = nil) {
        if view.alpha == alpha {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            view.alpha = alpha
            view.layer.removeAnimation(forKey: "opacity")
            completion?(true)
        case .curve:
            let previousAlpha: Float
            if view.layer.animation(forKey: "opacity") != nil {
                previousAlpha = view.layer.presentation()?.opacity ?? Float(view.alpha)
            } else {
                previousAlpha = Float(view.alpha)
            }
            view.alpha = alpha
            self.animateAlpha(layer: view.layer, from: CGFloat(previousAlpha), to: alpha, delay: delay, completion: completion)
        }
    }

    public func setAlpha(layer: CALayer, alpha: CGFloat, delay: Double = 0.0, completion: ((Bool) -> Void)? = nil) {
        if layer.opacity == Float(alpha) {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            layer.opacity = Float(alpha)
            layer.removeAnimation(forKey: "opacity")
            completion?(true)
        case .curve:
            let previousAlpha: Float
            if layer.animation(forKey: "opacity") != nil {
                previousAlpha = layer.presentation()?.opacity ?? layer.opacity
            } else {
                previousAlpha = layer.opacity
            }
            layer.opacity = Float(alpha)
            self.animateAlpha(layer: layer, from: CGFloat(previousAlpha), to: alpha, delay: delay, completion: completion)
        }
    }

    public func setScale(view: UIView, scale: CGFloat, delay: Double = 0.0, completion: ((Bool) -> Void)? = nil) {
        self.setScale(layer: view.layer, scale: scale, delay: delay, completion: completion)
    }

    public func setScale(layer: CALayer, scale: CGFloat, delay: Double = 0.0, beginWithCurrentState: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let currentTransform: CATransform3D
        if beginWithCurrentState, layer.animation(forKey: "transform") != nil || layer.animation(forKey: "transform.scale") != nil {
            currentTransform = layer.presentation()?.transform ?? layer.transform
        } else {
            currentTransform = layer.transform
        }
        
        let currentScale = sqrt((currentTransform.m11 * currentTransform.m11) + (currentTransform.m12 * currentTransform.m12) + (currentTransform.m13 * currentTransform.m13))
        if currentScale == scale {
            if let animation = layer.animation(forKey: "transform.scale") as? CABasicAnimation, let toValue = animation.toValue as? NSNumber {
                if toValue.doubleValue == scale {
                    completion?(true)
                    return
                }
            } else {
                completion?(true)
                return
            }
        }
        switch self.animation {
        case .none:
            layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
            completion?(true)
        case let .curve(duration, curve):
            let previousScale = currentScale
            layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
            layer.animate(
                from: previousScale as NSNumber,
                to: scale as NSNumber,
                keyPath: "transform.scale",
                duration: duration,
                delay: delay,
                curve: curve,
                removeOnCompletion: true,
                additive: false,
                completion: completion
            )
        }
    }

    public func setCornerRadius(layer: CALayer, cornerRadius: CGFloat, completion: ((Bool) -> Void)? = nil) {
        if layer.cornerRadius == cornerRadius {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            layer.cornerRadius = cornerRadius
            completion?(true)
        case let .curve(duration, curve):
            let fromValue: CGFloat
            if layer.animation(forKey: "cornerRadius") != nil, let presentation = layer.presentation() {
                fromValue = presentation.cornerRadius
            } else {
                fromValue = layer.cornerRadius
            }
            layer.cornerRadius = cornerRadius
            layer.animate(
                from: fromValue as NSNumber,
                to: cornerRadius as NSNumber,
                keyPath: "cornerRadius",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: false,
                completion: completion
            )
        }
    }

    public func setBlur(layer: CALayer, radius: CGFloat, completion: ((Bool) -> Void)? = nil) {
        var currentRadius: CGFloat = 0.0
        if let currentFilters = layer.filters {
            for filter in currentFilters {
                if let filter = filter as? NSObject, filter.description.contains("gaussianBlur") {
                    currentRadius = filter.value(forKey: "inputRadius") as? CGFloat ?? 0.0
                }
            }
        }

        if currentRadius == radius {
            completion?(true)
            return
        }

        if let blurFilter = CALayer.blur() {
            blurFilter.setValue(radius as NSNumber, forKey: "inputRadius")
            layer.filters = [blurFilter]
            switch self.animation {
            case .none:
                completion?(true)
            case let .curve(duration, curve):
                layer.animate(from: currentRadius as NSNumber, to: radius as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", duration: duration, delay: 0.0, curve: curve, removeOnCompletion: true, additive: false,completion: { [weak layer] flag in
                    if let layer {
                        if radius <= 0.0 {
                            layer.filters = nil
                        }
                    }
                    
                    completion?(flag)
                })
            }
        }
    }

    public func setBackgroundColor(view: UIView, color: UIColor, completion: ((Bool) -> Void)? = nil) {
        self.setBackgroundColor(layer: view.layer, color: color, completion: completion)
    }

    public func setBackgroundColor(layer: CALayer, color: UIColor, completion: ((Bool) -> Void)? = nil) {
        if let current = layer.backgroundColor, current == color.cgColor {
            completion?(true)
            return
        }
        
        switch self.animation {
        case .none:
            layer.backgroundColor = color.cgColor
            completion?(true)
        case let .curve(duration, curve):
            let previousColor: CGColor = layer.backgroundColor ?? UIColor.clear.cgColor
            layer.backgroundColor = color.cgColor
            
            layer.animate(
                from: previousColor,
                to: color.cgColor,
                keyPath: "backgroundColor",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: false,
                completion: completion
            )
        }
    }

    public func setTintColor(view: UIView, color: UIColor, completion: ((Bool) -> Void)? = nil) {
        if let current = view.tintColor, current == color {
            completion?(true)
            return
        }
        
        switch self.animation {
        case .none:
            view.tintColor = color
            completion?(true)
        case let .curve(duration, curve):
            let previousColor: UIColor = view.tintColor ?? UIColor.clear
            view.tintColor = color
            
            view.layer.animate(
                from: previousColor,
                to: color.cgColor,
                keyPath: "contentsMultiplyColor",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: false,
                completion: completion
            )
        }
    }



    public func animateScale(view: UIView, from fromValue: CGFloat, to toValue: CGFloat, delay: Double = 0.0, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        self.animateScale(layer: view.layer, from: fromValue, to: toValue, delay: delay, additive: additive, completion: completion)
    }

    public func animateScale(layer: CALayer, from fromValue: CGFloat, to toValue: CGFloat, delay: Double = 0.0, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            layer.animate(
                from: fromValue as NSNumber,
                to: toValue as NSNumber,
                keyPath: "transform.scale",
                duration: duration,
                delay: delay,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }

    public func animateAlpha(view: UIView, from fromValue: CGFloat, to toValue: CGFloat, delay: Double = 0.0, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        self.animateAlpha(layer: view.layer, from: fromValue, to: toValue, delay: delay, additive: additive, completion: completion)
    }

    public func animateAlpha(layer: CALayer, from fromValue: CGFloat, to toValue: CGFloat, delay: Double = 0.0, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            layer.animate(
                from: fromValue as NSNumber,
                to: toValue as NSNumber,
                keyPath: "opacity",
                duration: duration,
                delay: delay,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }

    public func animatePosition(view: UIView, from fromValue: CGPoint, to toValue: CGPoint, delay: Double = 0.0, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        self.animatePosition(layer: view.layer, from: fromValue, to: toValue, delay: delay, additive: additive, completion: completion)
    }

    public func animatePosition(layer: CALayer, from fromValue: CGPoint, to toValue: CGPoint, delay: Double = 0.0, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            layer.animate(
                from: NSValue(cgPoint: fromValue),
                to: NSValue(cgPoint: toValue),
                keyPath: "position",
                duration: duration,
                delay: delay,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }

    public func animateBounds(view: UIView, from fromValue: CGRect, to toValue: CGRect, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        self.animateBounds(layer: view.layer, from: fromValue, to: toValue, additive: additive, completion: completion)
    }

    public func animateBounds(layer: CALayer, from fromValue: CGRect, to toValue: CGRect, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            layer.animate(
                from: NSValue(cgRect: fromValue),
                to: NSValue(cgRect: toValue),
                keyPath: "bounds",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }

    public func animateBoundsOrigin(view: UIView, from fromValue: CGPoint, to toValue: CGPoint, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        self.animateBoundsOrigin(layer: view.layer, from: fromValue, to: toValue, additive: additive, completion: completion)
    }

    public func animateBoundsOrigin(layer: CALayer, from fromValue: CGPoint, to toValue: CGPoint, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            layer.animate(
                from: NSValue(cgPoint: fromValue),
                to: NSValue(cgPoint: toValue),
                keyPath: "bounds.origin",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }

    public func animateBoundsSize(view: UIView, from fromValue: CGSize, to toValue: CGSize, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        self.animateBoundsSize(layer: view.layer, from: fromValue, to: toValue, additive: additive, completion: completion)
    }

    public func animateBoundsSize(layer: CALayer, from fromValue: CGSize, to toValue: CGSize, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            layer.animate(
                from: NSValue(cgSize: fromValue),
                to: NSValue(cgSize: toValue),
                keyPath: "bounds.size",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }

    public func animateView(allowUserInteraction: Bool = true, delay: Double = 0.0, _ animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            animations()
            completion?(true)
        case let .curve(duration, curve):
            let timing: UITimingCurveProvider
            switch curve {
            case .spring:
                // UIViewController+Navigation.m keeps the native spring only
                // for 0.3832/0.5 seconds; its other "spring" transitions use
                // this exact cubic curve. The tab bar uses 0.4 seconds.
                if abs(duration - 0.3832) <= 0.0001 || abs(duration - 0.5) <= 0.0001 {
                    timing = UISpringTimingParameters(mass: 1.0, stiffness: 555.027, damping: 47.118, initialVelocity: .zero)
                } else {
                    timing = UICubicTimingParameters(controlPoint1: CGPoint(x: 0.380, y: 0.700), controlPoint2: CGPoint(x: 0.125, y: 1.000))
                }
            case let .bounce(stiffness, damping):
                timing = UISpringTimingParameters(mass: 5.0, stiffness: stiffness, damping: damping, initialVelocity: .zero)
            case let .custom(a, b, c, d):
                timing = UICubicTimingParameters(controlPoint1: CGPoint(x: CGFloat(a), y: CGFloat(b)), controlPoint2: CGPoint(x: CGFloat(c), y: CGFloat(d)))
            case .easeInOut:
                timing = UICubicTimingParameters(animationCurve: .easeInOut)
            case .easeIn:
                timing = UICubicTimingParameters(animationCurve: .easeIn)
            case .linear:
                timing = UICubicTimingParameters(animationCurve: .linear)
            }
            let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timing)
            animator.isUserInteractionEnabled = allowUserInteraction
            animator.addAnimations(animations)
            if let completion { animator.addCompletion { completion($0 == .end) } }
            animator.startAnimation(afterDelay: delay)
        }
    }
}

public extension UIView {
    func setMonochromaticEffect(tintColor: UIColor?) {
        var overrideUserInterfaceStyle: UIUserInterfaceStyle = .unspecified
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 1.0
        if let tintColor {
            if tintColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                if red == 0.0 && green == 0.0 && blue == 0.0 && alpha == 1.0 {
                    overrideUserInterfaceStyle = .light
                }
            } else {
                if red == 1.0 && green == 1.0 && blue == 1.0 && alpha == 1.0 {
                    overrideUserInterfaceStyle = .dark
                }
            }
        }
        
        if self.overrideUserInterfaceStyle != overrideUserInterfaceStyle {
            self.overrideUserInterfaceStyle = overrideUserInterfaceStyle
            setMonochromaticEffectImpl(self, overrideUserInterfaceStyle != .unspecified)
        }
    }
}

private func setMonochromaticEffectImpl(_ view: UIView, _ isEnabled: Bool) {
    for name in ["_setAllowsMonochromaticTreatment:", "_setEnableMonochromaticTreatment:"] {
        let selector = NSSelectorFromString(name)
        if view.responds(to: selector), let implementation = view.method(for: selector) {
            typealias Setter = @convention(c) (AnyObject, Selector, Bool) -> Void
            unsafeBitCast(implementation, to: Setter.self)(view, selector, isEnabled)
        }
    }
    let selector = NSSelectorFromString("_setMonochromaticTreatment:")
    if view.responds(to: selector), let implementation = view.method(for: selector) {
        typealias Setter = @convention(c) (AnyObject, Selector, Int64) -> Void
        unsafeBitCast(implementation, to: Setter.self)(view, selector, isEnabled ? 2 : 0)
    }
}
