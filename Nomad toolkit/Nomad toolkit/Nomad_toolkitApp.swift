//
//  Nomad_toolkitApp.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import SwiftUI

@main
struct Nomad_toolkitApp: App {
    @StateObject private var userViewModel = UserViewModel()
    @State private var deepLinkDestination: String?

    init() {
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if userViewModel.isLoggedIn {
                    ContentView()
                        .environmentObject(userViewModel)
                        .transition(.opacity)
                } else {
                    LoginView(
                        isLoggedIn: Binding(
                            get: { userViewModel.isLoggedIn },
                            set: { newValue in
                                if newValue {
                                    userViewModel.isLoggedIn = true
                                }
                            }
                        ),
                        userViewModel: userViewModel
                    )
                    .transition(.opacity)
                }
            }
            .preferredColorScheme(.light) // 强制白天模式
            .onOpenURL { url in
                deepLinkDestination = url.host()
            }
            .environment(\.deepLinkDestination, deepLinkDestination)
        }
    }
}

extension View {
    func forceLightMode() -> some View {
        self.preferredColorScheme(.light)
    }
}
