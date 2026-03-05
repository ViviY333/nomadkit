import WidgetKit
import SwiftUI

struct TranslationEntry: TimelineEntry {
    let date: Date
    let fromLanguage: Language?
    let toLanguage: Language?
}

struct TranslationProvider: TimelineProvider {
    func placeholder(in context: Context) -> TranslationEntry {
        TranslationEntry(date: .now, fromLanguage: nil, toLanguage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TranslationEntry) -> Void) {
        let (from, to) = loadLanguages()
        completion(TranslationEntry(date: .now, fromLanguage: from, toLanguage: to))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TranslationEntry>) -> Void) {
        let (from, to) = loadLanguages()
        let entry = TranslationEntry(date: .now, fromLanguage: from, toLanguage: to)
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func loadLanguages() -> (Language?, Language?) {
        let from: Language? = {
            guard let data = SharedDefaults.store.data(forKey: "lastFromLanguage") else { return nil }
            return try? JSONDecoder().decode(Language.self, from: data)
        }()
        let to: Language? = {
            guard let data = SharedDefaults.store.data(forKey: "lastToLanguage") else { return nil }
            return try? JSONDecoder().decode(Language.self, from: data)
        }()
        return (from, to)
    }
}

struct TranslationWidgetView: View {
    let entry: TranslationEntry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 24))
                .foregroundStyle(.purple)

            if let from = entry.fromLanguage, let to = entry.toLanguage {
                Text("\(from.name) \u{2192} \(to.name)")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("Translation")
                    .font(.system(size: 15, weight: .semibold))
            }

            Text("Tap to translate")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .widgetURL(URL(string: "nomadkit://translation"))
    }
}

struct TranslationWidget: Widget {
    let kind = "TranslationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TranslationProvider()) { entry in
            TranslationWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Translation")
        .description("Tap to open translator")
        .supportedFamilies([.systemSmall])
    }
}
