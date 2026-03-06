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
        VStack(alignment: .leading, spacing: 10) {
            // Top row: title (left) + overlapping flags (right)
            HStack {
                Text("Translation")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                if let from = entry.fromLanguage, let to = entry.toLanguage {
                    ZStack {
                        Text(to.flag)
                            .font(.system(size: 28))
                            .frame(width: 36, height: 36)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            .offset(x: 10, y: 10)

                        Text(from.flag)
                            .font(.system(size: 28))
                            .frame(width: 36, height: 36)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .frame(width: 50, height: 50)
                }
            }

            // Placeholder text area
            Text("Input the text...")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

            Spacer()

            // Bottom toolbar: camera, photo, mic icons + send button
            HStack(spacing: 24) {
                Image(systemName: "camera")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                Spacer()
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black)
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .widgetURL(URL(string: "nomadkit://translation"))
    }
}

struct TranslationWidget: Widget {
    let kind = "TranslationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TranslationProvider()) { entry in
            TranslationWidgetView(entry: entry)
                .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName("Translation")
        .description("Tap to open translator")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
