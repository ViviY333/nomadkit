import WidgetKit
import SwiftUI

struct WeatherEntry: TimelineEntry {
    let date: Date
    let weather: Weather?
}

struct WeatherProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: .now, weather: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        completion(WeatherEntry(date: .now, weather: loadCachedWeather()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        Task {
            let weather = await fetchOrLoadWeather()
            let entry = WeatherEntry(date: .now, weather: weather)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func loadCachedWeather() -> Weather? {
        guard let data = SharedDefaults.store.data(forKey: "lastWeather") else { return nil }
        return try? JSONDecoder().decode(Weather.self, from: data)
    }

    private func fetchOrLoadWeather() async -> Weather? {
        if let cityName = SharedDefaults.store.string(forKey: "selectedCity") {
            return try? await WeatherService().fetchWeather(for: cityName)
        }
        return loadCachedWeather()
    }
}

struct WeatherWidgetView: View {
    let entry: WeatherEntry

    var body: some View {
        if let weather = entry.weather {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: weather.conditionIconCode)
                        .font(.system(size: 20))
                        .symbolRenderingMode(.multicolor)
                    Spacer()
                    Text("\(Int(weather.temperatureC))\u{00B0}")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                Spacer()
                Text(weather.cityName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(weather.conditionText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if let aqi = weather.airQualityIndex {
                    Text("AQI \(aqi)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        } else {
            VStack {
                Image(systemName: "cloud.sun")
                    .font(.system(size: 24))
                Text("Open app to setup")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
        }
    }
}

struct WeatherWidget: Widget {
    let kind = "WeatherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherProvider()) { entry in
            WeatherWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weather")
        .description("Current weather for your city")
        .supportedFamilies([.systemSmall])
    }
}
