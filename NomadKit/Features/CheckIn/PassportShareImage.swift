import SwiftUI
import UIKit

struct PassportShareContent: Equatable {
    let travelerName: String
    let cityNames: [String]
    let stats: TravelStats
    let badgeCount: Int
    let generatedAt: Date
}

struct RenderedPassport: Identifiable {
    let id = UUID()
    let image: UIImage
}

@MainActor
enum PassportImageRenderer {
    static let outputSize = CGSize(width: 1_080, height: 1_920)

    static func render(content: PassportShareContent, locale: Locale = .current) -> UIImage? {
        let card = PassportShareCard(content: content)
            .frame(width: 360, height: 640)
            .environment(\.colorScheme, .dark)
            .environment(\.locale, locale)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

struct PassportShareCard: View {
    @Environment(\.locale) private var locale
    let content: PassportShareContent

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.nomadInk,
                    Color(red: 0.11, green: 0.24, blue: 0.46),
                    Color.nomadBlue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 330, weight: .thin))
                .foregroundStyle(.white.opacity(0.055))
                .offset(x: 92, y: -110)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("checkin.passport.name", systemImage: "person.text.rectangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("NOMAD KIT · 02")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                }
                .foregroundStyle(.white.opacity(0.9))

                Spacer()

                Text("passport.image.eyebrow")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.nomadYellow)

                Text(title)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .tracking(-1.2)
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                Text(content.cityNames.joined(separator: " · "))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineSpacing(5)
                    .lineLimit(4)
                    .padding(.top, 20)

                Spacer()

                HStack(spacing: 0) {
                    ShareStat(value: content.stats.cityCount, label: "checkin.stat.cities")
                    ShareStat(value: content.stats.countryCount, label: "checkin.stat.countries")
                    ShareStat(value: content.stats.totalDays, label: "checkin.stat.days")
                    ShareStat(value: content.badgeCount, label: "passport.image.badges")
                }
                .padding(.vertical, 20)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 0.5)
                }

                HStack {
                    Text("passport.image.footer")
                    Spacer()
                    Text(content.generatedAt, format: .dateTime.year().month(.twoDigits).day(.twoDigits))
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .padding(.top, 22)
            }
            .padding(28)
        }
        .clipped()
    }

    private var title: String {
        guard !content.travelerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return appLocalized("passport.image.title", locale: locale)
        }
        let format = appLocalized("passport.image.named.title", locale: locale)
        return String.localizedStringWithFormat(format, content.travelerName)
    }
}

private struct ShareStat: View {
    let value: Int
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 5) {
            Text(value, format: .number)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
