import SwiftUI

enum NomadSpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
    static let section: CGFloat = 32
}

extension Color {
    static let nomadBackground = Color.white
    static let nomadSurface = Color(red: 1.0, green: 0.965, blue: 0.89)
    static let nomadInk = Color(red: 0.047, green: 0.098, blue: 0.216)
    static let nomadSky = Color.nomadInk
    static let nomadBlue = Color(red: 0.337, green: 0.592, blue: 0.973)
    static let nomadGreen = Color(red: 0.404, green: 0.843, blue: 0.627)
    static let nomadYellow = Color(red: 0.965, green: 0.792, blue: 0.267)
    static let nomadPink = Color(red: 0.957, green: 0.325, blue: 0.243)
    static let nomadLavender = Color(red: 0.761, green: 0.796, blue: 0.867)

    static func tone(_ tone: SystemTone) -> Color {
        switch tone {
        case .blue: .nomadBlue
        case .orange: .nomadYellow
        case .green: .nomadGreen
        case .teal: .nomadGreen
        case .indigo: .nomadInk
        case .pink: .nomadPink
        }
    }
}

struct NomadSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(NomadSpacing.large)
            .background(Color.nomadSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.045), radius: 18, y: 8)
    }
}

extension View {
    func nomadSurface() -> some View {
        modifier(NomadSurfaceModifier())
    }
}

struct PressableScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(reduceMotion ? nil : .smooth(duration: 0.16), value: configuration.isPressed)
    }
}
