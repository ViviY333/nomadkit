import SwiftUI

enum VastagoWeight {
    case regular
    case medium
    case semibold
    case bold

    var postScriptName: String {
        switch self {
        case .regular: "VastagoGrotesk-Regular"
        case .medium: "VastagoGrotesk-Medium"
        case .semibold: "VastagoGrotesk-SemiBold"
        case .bold: "VastagoGrotesk-Bold"
        }
    }
}

extension Font {
    static func vastago(_ size: CGFloat, weight: VastagoWeight = .regular, relativeTo style: TextStyle = .body) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: style)
    }

    static func onboarding(_ size: CGFloat, weight: VastagoWeight = .regular, relativeTo style: TextStyle = .body) -> Font {
        if Locale.autoupdatingCurrent.language.languageCode?.identifier == "zh" {
            let systemWeight: Weight = switch weight {
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            case .bold: .bold
            }
            return .system(size: size, weight: systemWeight, design: .rounded)
        }
        return .vastago(size, weight: weight, relativeTo: style)
    }
}
