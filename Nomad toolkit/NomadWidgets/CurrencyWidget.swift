import WidgetKit
import SwiftUI

struct CurrencyEntry: TimelineEntry {
    let date: Date
    let fromCurrency: Currency?
    let toCurrency: Currency?
}

struct CurrencyProvider: TimelineProvider {
    func placeholder(in context: Context) -> CurrencyEntry {
        CurrencyEntry(date: .now, fromCurrency: nil, toCurrency: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrencyEntry) -> Void) {
        let (from, to) = loadCurrencies()
        completion(CurrencyEntry(date: .now, fromCurrency: from, toCurrency: to))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrencyEntry>) -> Void) {
        let (from, to) = loadCurrencies()
        let entry = CurrencyEntry(date: .now, fromCurrency: from, toCurrency: to)
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func loadCurrencies() -> (Currency?, Currency?) {
        let from: Currency? = {
            guard let data = SharedDefaults.store.data(forKey: "lastFromCurrency") else { return nil }
            return try? JSONDecoder().decode(Currency.self, from: data)
        }()
        let to: Currency? = {
            guard let data = SharedDefaults.store.data(forKey: "lastToCurrency") else { return nil }
            return try? JSONDecoder().decode(Currency.self, from: data)
        }()
        return (from, to)
    }
}

struct CurrencyWidgetView: View {
    let entry: CurrencyEntry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "dollarsign.arrow.circlepath")
                .font(.system(size: 24))
                .foregroundStyle(.blue)

            if let from = entry.fromCurrency, let to = entry.toCurrency {
                Text("\(from.id) \u{2192} \(to.id)")
                    .font(.system(size: 15, weight: .semibold))
            } else {
                Text("Currency")
                    .font(.system(size: 15, weight: .semibold))
            }

            Text("Tap to convert")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .widgetURL(URL(string: "nomadkit://currency"))
    }
}

struct CurrencyWidget: Widget {
    let kind = "CurrencyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrencyProvider()) { entry in
            CurrencyWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Currency Converter")
        .description("Tap to open currency converter")
        .supportedFamilies([.systemSmall])
    }
}
