import WidgetKit
import SwiftUI

struct TimeZoneEntry: TimelineEntry {
    let date: Date
    let timeZones: [TimeZoneItem]
}

struct TimeZoneProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimeZoneEntry {
        TimeZoneEntry(date: .now, timeZones: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (TimeZoneEntry) -> Void) {
        completion(TimeZoneEntry(date: .now, timeZones: loadTimeZones()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimeZoneEntry>) -> Void) {
        let entry = TimeZoneEntry(date: .now, timeZones: loadTimeZones())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadTimeZones() -> [TimeZoneItem] {
        guard let data = SharedDefaults.store.data(forKey: "savedTimeZones"),
              let zones = try? JSONDecoder().decode([TimeZoneItem].self, from: data) else {
            return []
        }
        return Array(zones.prefix(4))
    }
}

struct TimeZoneWidgetView: View {
    let entry: TimeZoneEntry

    var body: some View {
        if entry.timeZones.isEmpty {
            VStack {
                Image(systemName: "clock")
                    .font(.system(size: 24))
                Text("Open app to add\ntime zones")
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.timeZones) { zone in
                    HStack {
                        Text(zone.cityName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text(timeString(for: zone))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                }
            }
            .padding()
        }
    }

    private func timeString(for zone: TimeZoneItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: zone.timeZoneIdentifier)
        return formatter.string(from: entry.date)
    }
}

struct TimeZoneWidget: Widget {
    let kind = "TimeZoneWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeZoneProvider()) { entry in
            TimeZoneWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Time Zones")
        .description("Your saved time zones at a glance")
        .supportedFamilies([.systemSmall])
    }
}
