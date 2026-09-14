import SwiftUI
import UIKit

/// A fixed set of tabs driven by an external navigation bar. UIKit retains each
/// hosting controller and manages appearance callbacks for the selected screen.
struct ScreenTransitionView<Item: Hashable, Content: View>: UIViewControllerRepresentable {
    let items: [Item]
    let selection: Item
    @ViewBuilder let content: (Item) -> Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UITabBarController {
        let controller = UITabBarController()
        controller.setTabBarHidden(true, animated: false)
        controller.viewControllers = items.map { item in
            UIHostingController(rootView: content(item))
        }
        controller.selectedIndex = items.firstIndex(of: selection) ?? 0
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UITabBarController, context: Context) {
        for (item, child) in zip(items, controller.viewControllers ?? []) {
            (child as? UIHostingController<Content>)?.rootView = content(item)
        }
        context.coordinator.reduceMotion = context.environment.accessibilityReduceMotion
        context.coordinator.select(items.firstIndex(of: selection) ?? 0, in: controller)
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        var reduceMotion = false
        private var isTransitioning = false
        private var requestedIndex = 0

        func select(_ index: Int, in controller: UITabBarController) {
            requestedIndex = index
            guard !isTransitioning, controller.selectedIndex != index else { return }
            controller.selectedIndex = index
        }

        func tabBarController(
            _ tabBarController: UITabBarController,
            animationControllerForTransitionFrom fromVC: UIViewController,
            to toVC: UIViewController
        ) -> (any UIViewControllerAnimatedTransitioning)? {
            isTransitioning = true
            return ScreenTransitionAnimator(duration: reduceMotion ? 0 : 0.14) { [weak self, weak tabBarController] in
                // Finish UIKit's transition before handling a newer tap. Rapid
                // taps coalesce to the latest destination without overlapping fades.
                DispatchQueue.main.async {
                    guard let self, let tabBarController else { return }
                    self.isTransitioning = false
                    self.select(self.requestedIndex, in: tabBarController)
                }
            }
        }
    }
}

private final class ScreenTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let duration: TimeInterval
    let completion: () -> Void

    init(duration: TimeInterval, completion: @escaping () -> Void) {
        self.duration = duration
        self.completion = completion
    }

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        duration
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let destination = transitionContext.viewController(forKey: .to),
              let outgoing = transitionContext.view(forKey: .from),
              let incoming = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)
            completion()
            return
        }

        let container = transitionContext.containerView
        UIView.performWithoutAnimation {
            container.addSubview(outgoing)
            incoming.frame = transitionContext.finalFrame(for: destination)
            // Attach behind the outgoing screen so safe areas and navigation
            // chrome settle in their actual container before the fade begins.
            container.insertSubview(incoming, belowSubview: outgoing)
            container.setNeedsLayout()
            container.layoutIfNeeded()
            incoming.setNeedsLayout()
            incoming.layoutIfNeeded()
            incoming.isHidden = true
        }

        UIView.transition(
            from: outgoing,
            to: incoming,
            duration: duration,
            options: [.transitionCrossDissolve, .curveEaseInOut, .showHideTransitionViews]
        ) { _ in
            let completed = !transitionContext.transitionWasCancelled
            if completed {
                outgoing.removeFromSuperview()
            } else {
                incoming.removeFromSuperview()
            }
            // UIKit's show/hide transition leaves the source hidden. Restore
            // both retained views so they are ready for subsequent selections.
            outgoing.isHidden = false
            incoming.isHidden = false
            transitionContext.completeTransition(completed)
            self.completion()
        }
    }
}
