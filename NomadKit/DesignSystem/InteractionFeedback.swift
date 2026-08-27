import SwiftUI
import UIKit
import ObjectiveC

enum NomadHaptics {
    enum Event {
        case tap
        case selection
        case navigation
        case lift
        case reorder
        case drop
        case success
        case warning
        case delete
    }

    static func play(_ event: Event) {
        let feedback = {
            switch event {
            case .tap:
                impact(style: .light, intensity: 0.55)
            case .selection:
                let generator = UISelectionFeedbackGenerator()
                generator.prepare()
                generator.selectionChanged()
            case .navigation:
                impact(style: .soft, intensity: 0.7)
            case .lift:
                impact(style: .medium, intensity: 0.72)
            case .reorder:
                impact(style: .rigid, intensity: 0.42)
            case .drop:
                impact(style: .soft, intensity: 0.82)
            case .success:
                notification(.success)
            case .warning, .delete:
                notification(.warning)
            }
        }

        if Thread.isMainThread {
            feedback()
        } else {
            DispatchQueue.main.async(execute: feedback)
        }
    }

    private static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }

    private static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

struct NomadPressFeedbackModifier: ViewModifier {
    let isPressed: Bool

    func body(content: Content) -> some View {
        content.onChange(of: isPressed) { wasPressed, isPressed in
            guard !wasPressed, isPressed else { return }
            NomadHaptics.play(.tap)
        }
    }
}

struct NomadPlainButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .smooth(duration: 0.14), value: configuration.isPressed)
            .modifier(NomadPressFeedbackModifier(isPressed: configuration.isPressed))
    }
}

extension View {
    func nomadHapticTap(_ event: NomadHaptics.Event = .tap) -> some View {
        simultaneousGesture(TapGesture().onEnded { NomadHaptics.play(event) })
    }

    func nomadInteractiveBackGesture() -> some View {
        background(NavigationBackGestureAccessor())
    }
}

private struct NavigationBackGestureAccessor: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> NavigationBackGestureController {
        NavigationBackGestureController()
    }

    func updateUIViewController(_ uiViewController: NavigationBackGestureController, context: Context) {
        uiViewController.connectIfNeeded()
    }
}

private final class NavigationBackGestureController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        connectIfNeeded()
    }

    func connectIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let gesture = self.navigationController?.interactivePopGestureRecognizer else { return }
            gesture.isEnabled = true
            guard objc_getAssociatedObject(gesture, &navigationBackHapticKey) == nil else { return }
            let target = NavigationBackHapticTarget()
            gesture.addTarget(target, action: #selector(NavigationBackHapticTarget.handle(_:)))
            objc_setAssociatedObject(
                gesture,
                &navigationBackHapticKey,
                target,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

private var navigationBackHapticKey: UInt8 = 0

private final class NavigationBackHapticTarget: NSObject {
    @objc func handle(_ gesture: UIGestureRecognizer) {
        guard gesture.state == .began else { return }
        NomadHaptics.play(.navigation)
    }
}
