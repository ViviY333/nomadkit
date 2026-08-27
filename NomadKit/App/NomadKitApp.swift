import SwiftUI

@main
struct NomadKitApp: App {
    @State private var userData = UserDataStore()
    @State private var subscriptionStore = SubscriptionStore()
    @State private var subscriptionPreviewDismissed = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showsSubscriptionPreview && !subscriptionPreviewDismissed {
                    SubscriptionPaywallView(entryPoint: .settings) {
                        subscriptionPreviewDismissed = true
                    }
                } else if userData.onboardingCompleted {
                    RootTabView()
                } else {
                    OnboardingView()
                }
            }
            .environment(userData)
            .environment(subscriptionStore)
            .environment(\.locale, appLocale)
            .preferredColorScheme(userData.appearancePreference.colorScheme)
            .tint(Color.nomadInk)
            .foregroundStyle(Color.nomadInk)
            .buttonStyle(PressableScaleButtonStyle())
        }
    }

    private var showsSubscriptionPreview: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-show-subscription-paywall")
#else
        false
#endif
    }

    private var appLocale: Locale {
#if DEBUG
        if userData.onboardingCompleted && ProcessInfo.processInfo.arguments.contains("-subscription-language-zh-Hans") {
            return Locale(identifier: "zh-Hans")
        }
#endif
        if !userData.onboardingCompleted {
            return .autoupdatingCurrent
        }
        return Locale(identifier: userData.preferredLanguageCode.isEmpty ? "en" : userData.preferredLanguageCode)
    }
}
