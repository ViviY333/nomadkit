import SwiftUI

struct RootTabView: View {
    @Environment(UserDataStore.self) private var userData
    @State private var selection: RootTab = {
        if ProcessInfo.processInfo.arguments.contains("-show-nomad-map") { return .checkIn }
        if ProcessInfo.processInfo.arguments.contains("-show-checklist") { return .checklist }
        return .today
    }()

    init() {
        UITabBar.appearance().unselectedItemTintColor = UIColor(Color.nomadTabInactive)
    }

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tag(RootTab.today)
                .tabItem {
                    Image(selection == .today ? "TabHomeFill" : "TabHomeOutline")
                        .renderingMode(.template)
                        .accessibilityLabel("tab.today")
                }

            ChecklistView()
                .tag(RootTab.checklist)
                .tabItem {
                    Image(selection == .checklist ? "TabChecklistFill" : "TabChecklistOutline")
                        .renderingMode(.template)
                        .accessibilityLabel("tab.checklist")
                }

            CheckInView()
                .tag(RootTab.checkIn)
                .tabItem {
                    Image(selection == .checkIn ? "TabGlobeFill" : "TabGlobeOutline")
                        .renderingMode(.template)
                        .accessibilityLabel("tab.checkin")
                }
        }
        .tint(selection == .checkIn ? .white : Color.nomadInk)
        .toolbarBackground(selection == .checkIn ? Color.black.opacity(0.78) : Color.nomadBackground, for: .tabBar)
        .toolbarColorScheme(selection == .checkIn ? .dark : .light, for: .tabBar)
        .sensoryFeedback(.selection, trigger: selection)
        .environment(userData)
    }
}

private enum RootTab: Hashable {
    case today
    case checklist
    case checkIn
}
