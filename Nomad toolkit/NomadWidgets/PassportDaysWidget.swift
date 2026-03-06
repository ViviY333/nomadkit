import WidgetKit
import SwiftUI

struct PassportEntry: TimelineEntry {
    let date: Date
    let currentDay: Int
    let stayDays: Int?
    let userName: String?
}

struct PassportProvider: TimelineProvider {
    func placeholder(in context: Context) -> PassportEntry {
        PassportEntry(date: .now, currentDay: 1, stayDays: nil, userName: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PassportEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PassportEntry>) -> Void) {
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [loadEntry()], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> PassportEntry {
        let store = SharedDefaults.store
        let loginDate = store.object(forKey: "loginDate") as? Date
        let currentDay: Int
        if let loginDate {
            let days = Calendar.current.dateComponents([.day], from: loginDate, to: Date()).day ?? 0
            currentDay = max(1, days + 1)
        } else {
            currentDay = 1
        }
        let stayDays = store.object(forKey: "passportStayDays") as? Int
        let userName = store.string(forKey: "userName")
        return PassportEntry(date: .now, currentDay: currentDay, stayDays: stayDays, userName: userName)
    }
}

struct PassportDaysWidgetView: View {
    let entry: PassportEntry

    var body: some View {
        VStack(spacing: 4) {
            Spacer()

            // Day counter matching nav bar style: "Day1(90)"
            if let stayDays = entry.stayDays {
                Text("Day\(entry.currentDay)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("(\(stayDays))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)

                let remaining = max(0, stayDays - entry.currentDay)
                HStack(spacing: 4) {
                    Circle()
                        .fill(remaining <= 3 ? Color.red : Color.green)
                        .frame(width: 6, height: 6)
                    Text("\(remaining) days left")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(remaining <= 3 ? .red : .secondary)
                }
                .padding(.top, 4)
            } else {
                Text("Day\(entry.currentDay)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Set stay days\nin app")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // User name at bottom
            if let name = entry.userName, !name.isEmpty {
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct PassportDaysWidget: Widget {
    let kind = "PassportDaysWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PassportProvider()) { entry in
            PassportDaysWidgetView(entry: entry)
                .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName("Passport Days")
        .description("Track your travel day count")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
