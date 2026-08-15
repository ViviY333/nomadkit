import SwiftUI

struct RootTabView: View {
    @Environment(UserDataStore.self) private var userData
    @State private var selection: RootTab = {
        if ProcessInfo.processInfo.arguments.contains("-show-nomad-map") { return .checkIn }
        if ProcessInfo.processInfo.arguments.contains("-show-checklist") { return .checklist }
        return .today
    }()

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tag(RootTab.today)
                .tabItem {
                    Image(selection == .today ? "TabHomeFill" : "TabHomeOutline")
                        .accessibilityLabel("tab.today")
                }

            ChecklistView()
                .tag(RootTab.checklist)
                .tabItem {
                    Image(selection == .checklist ? "TabChecklistFill" : "TabChecklistOutline")
                        .accessibilityLabel("tab.checklist")
                }

            CheckInView()
                .tag(RootTab.checkIn)
                .tabItem {
                    Image(selection == .checkIn ? "TabGlobeFill" : "TabGlobeOutline")
                        .accessibilityLabel("tab.checkin")
                }
        }
        .environment(userData)
    }
}

private enum RootTab: Hashable {
    case today
    case checklist
    case checkIn
}
