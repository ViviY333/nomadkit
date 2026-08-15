import SwiftUI

@main
struct NomadKitApp: App {
    @State private var userData = UserDataStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if userData.onboardingCompleted {
                    RootTabView()
                } else {
                    OnboardingView()
                }
            }
            .environment(userData)
            .environment(\.locale, userData.preferredLanguageCode.isEmpty ? .autoupdatingCurrent : Locale(identifier: userData.preferredLanguageCode))
            .tint(Color.nomadInk)
            .foregroundStyle(Color.nomadInk)
        }
    }
}
