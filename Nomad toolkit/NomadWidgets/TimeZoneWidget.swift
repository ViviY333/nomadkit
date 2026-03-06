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
            ZStack {
                // Blue gradient matching the app
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.09, green: 0.5, blue: 0.96),
                        Color(red: 0.02, green: 0.7, blue: 0.98)
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                VStack {
                    Image(systemName: "clock")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    Text("Open app to add\ntime zones")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
        } else {
            ZStack {
                // Blue gradient matching the app
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.09, green: 0.5, blue: 0.96),
                        Color(red: 0.02, green: 0.7, blue: 0.98)
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )

                VStack(spacing: 4) {
                    ForEach(entry.timeZones) { zone in
                        HStack(spacing: 0) {
                            Text(formattedTime(for: zone))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.leading, 10)

                            Text(amPm(for: zone))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.leading, 3)
                                .padding(.top, 4)

                            Spacer()

                            Text(abbreviation(for: zone))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                                .padding(.trailing, 10)
                        }
                        .frame(height: 30)
                        .background(
                            Image("bg")
                                .resizable()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        )
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
    }

    private func formattedTime(for zone: TimeZoneItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: zone.timeZoneIdentifier)
        return formatter.string(from: entry.date)
    }

    private func amPm(for zone: TimeZoneItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        formatter.timeZone = TimeZone(identifier: zone.timeZoneIdentifier)
        return formatter.string(from: entry.date)
    }

    private func abbreviation(for zone: TimeZoneItem) -> String {
        TimeZone(identifier: zone.timeZoneIdentifier)?.abbreviation() ?? zone.cityName
    }
}

struct TimeZoneWidget: Widget {
    let kind = "TimeZoneWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeZoneProvider()) { entry in
            TimeZoneWidgetView(entry: entry)
                .widgetURL(URL(string: "nomadkit://timezone"))
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Time Zones")
        .description("Your saved time zones at a glance")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
