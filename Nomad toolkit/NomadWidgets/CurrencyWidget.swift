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
        if let from = entry.fromCurrency, let to = entry.toCurrency {
            ZStack {
                VStack(spacing: 8) {
                    // From row
                    HStack {
                        Text("0.00")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer()
                        currencySelector(for: from)
                    }
                    .padding(12)
                    .background(Color(white: 0.96))
                    .cornerRadius(20)

                    // To row
                    HStack {
                        Text("0.00")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer()
                        currencySelector(for: to)
                    }
                    .padding(12)
                    .background(Color(white: 0.96))
                    .cornerRadius(20)
                }

                // Swap overlay
                ZStack {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
                        .frame(width: 36, height: 36)
                        .shadow(radius: 2)
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(14)
        } else {
            VStack {
                Image(systemName: "coloncurrencysign.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text("Tap to convert")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func currencySelector(for currency: Currency) -> some View {
        VStack(spacing: 2) {
            if let iconName = currency.iconName {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            } else {
                Text(currency.flag)
                    .font(.system(size: 20))
            }
            Text(currency.id)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
}

struct CurrencyWidget: Widget {
    let kind = "CurrencyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrencyProvider()) { entry in
            CurrencyWidgetView(entry: entry)
                .widgetURL(URL(string: "nomadkit://currency"))
                .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName("Currency Converter")
        .description("Tap to open currency converter")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
