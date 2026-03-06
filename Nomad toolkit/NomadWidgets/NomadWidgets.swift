import WidgetKit
import SwiftUI

struct WeatherEntry: TimelineEntry {
    let date: Date
    let weather: Weather?
    let bgImageName: String
}

struct WeatherProvider: TimelineProvider {
    private let bgImages = ["weather_bg_1", "weather_bg_2", "weather_bg_3"]

    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: .now, weather: nil, bgImageName: bgImages.randomElement()!)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        completion(WeatherEntry(date: .now, weather: loadCachedWeather(), bgImageName: bgImages.randomElement()!))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        Task {
            let weather = await fetchOrLoadWeather()
            let entry = WeatherEntry(date: .now, weather: weather, bgImageName: bgImages.randomElement()!)
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
            ZStack(alignment: .topLeading) {
                // Background image + dark overlay
                Image(entry.bgImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                Color.black.opacity(0.25)

                VStack(alignment: .leading, spacing: 0) {
                    // Top: icon left, temp + city right
                    HStack(alignment: .top) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: weather.conditionIconCode)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .symbolRenderingMode(.multicolor)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(weather.temperatureC))°C")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("\(weather.cityName), \(weather.countryCode)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 12)

                    Spacer()

                    // Bottom: AQI + Rain pills
                    HStack(spacing: 4) {
                        // AQI pill
                        HStack(spacing: 3) {
                            Text(weather.airQualityInfo.text)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Circle()
                                .fill(aqiColor(for: weather.airQualityInfo.color))
                                .frame(width: 5, height: 5)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.15))
                        )

                        // Rain pill
                        HStack(spacing: 3) {
                            Text("\(weather.rainChance ?? 0)%")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                            Image(systemName: "umbrella.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                                .symbolRenderingMode(.multicolor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        } else {
            ZStack {
                Image("weather_bg_1")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                Color.black.opacity(0.25)
                VStack {
                    Image(systemName: "cloud.sun")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    Text("Open app to setup")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }

    private func aqiColor(for colorName: String) -> Color {
        switch colorName {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "brown": return .brown
        default: return .gray
        }
    }
}

struct WeatherWidget: Widget {
    let kind = "WeatherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherProvider()) { entry in
            WeatherWidgetView(entry: entry)
                .widgetURL(URL(string: "nomadkit://weather"))
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Weather")
        .description("Current weather for your city")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
