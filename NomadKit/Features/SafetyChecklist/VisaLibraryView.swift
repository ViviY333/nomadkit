import SwiftUI

struct VisaLibraryView: View {
    @State private var viewModel = VisaLibraryViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if viewModel.articles.isEmpty, let error = viewModel.errorMessage {
                ContentUnavailableView(
                    String(localized: "visa.loadError.title", locale: locale),
                    systemImage: "passport",
                    description: Text(error)
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: NomadSpacing.xLarge) {
                        VisaLibraryHeader()
                        ForEach(viewModel.articles) { article in
                            NavigationLink {
                                VisaArticleView(article: article)
                            } label: {
                                VisaArticleCard(article: article)
                            }
                            .buttonStyle(PressableScaleButtonStyle())
                        }
                        VisaLibraryNotice()
                    }
                    .padding(.horizontal, NomadSpacing.large)
                    .padding(.bottom, NomadSpacing.section)
                }
                .background(Color.nomadBackground)
                .refreshable { viewModel.load() }
            }
        }
        .navigationTitle(String(localized: "visa.title", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct VisaLibraryHeader: View {
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: NomadSpacing.small) {
            Label(String(localized: "visa.header.eyebrow", locale: locale), systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text(String(localized: "visa.header.title", locale: locale))
                .font(.system(.title, design: .rounded, weight: .bold))
            Text(String(localized: "visa.header.subtitle", locale: locale))
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .padding(.top, NomadSpacing.small)
    }
}

private struct VisaArticleCard: View {
    let article: VisaArticle
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VisaArticleImage(article: article)
            LinearGradient(colors: [.black.opacity(0.72), .black.opacity(0.08), .clear], startPoint: .bottom, endPoint: .top)
            VStack(alignment: .leading, spacing: 7) {
                Text(article.country.value(for: locale))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.82))
                Text(article.title.value(for: locale))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Label(String.localizedStringWithFormat(String(localized: "visa.readTime", locale: locale), article.readTimeMinutes), systemImage: "clock")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .frame(height: 193)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

private struct VisaArticleImage: View {
    let article: VisaArticle

    var body: some View {
        Image(visaImageAsset(for: article.countryCode))
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }
}

private func visaImageAsset(for countryCode: String) -> String {
    switch countryCode {
    case "TH": "CityCoverBangkok"
    case "JP": "CityCoverTokyo"
    case "KR": "CityCoverTaipei"
    case "PT", "ES": "CityCoverLisbon"
    case "HR": "CityCoverBudapest"
    case "CO": "CityCoverMedellin"
    case "BR": "CityCoverBali"
    default: "VisaLibraryCover"
    }
}

private struct VisaLibraryNotice: View {
    @Environment(\.locale) private var locale
    var body: some View {
        Label(
            String(localized: "visa.disclaimer", locale: locale),
            systemImage: "exclamationmark.shield"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, NomadSpacing.small)
    }
}

struct VisaArticleView: View {
    let article: VisaArticle
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: NomadSpacing.xLarge) {
                VisaArticleHero(article: article)
                VisaFactStrip(facts: article.keyFacts, tone: article.tone)
                VisaNoticeBlock(notice: article.notice)

                ForEach(article.sections) { section in
                    VisaSectionView(section: section)
                }

                VisaSourcesSection(sources: article.sources, updatedAt: article.updatedAt)

                Text(article.disclaimer.value(for: locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .padding(.horizontal, NomadSpacing.small)
            }
            .padding(.horizontal, NomadSpacing.large)
            .padding(.bottom, NomadSpacing.section)
        }
        .background(Color.nomadBackground)
        .navigationTitle(article.country.value(for: locale))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct VisaArticleHero: View {
    let article: VisaArticle
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VisaArticleImage(article: article)
            LinearGradient(colors: [.black.opacity(0.78), .black.opacity(0.12), .clear], startPoint: .bottom, endPoint: .top)
            VStack(alignment: .leading, spacing: 8) {
                Label(article.country.value(for: locale), systemImage: article.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.84))
                Text(article.title.value(for: locale))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Label(String.localizedStringWithFormat(String(localized: "visa.readTime", locale: locale), article.readTimeMinutes), systemImage: "clock")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(height: 270)
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }
}

private struct VisaFactStrip: View {
    let facts: [VisaKeyFact]
    let tone: SystemTone
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: NomadSpacing.medium) {
                ForEach(facts) { fact in
                    VStack(alignment: .leading, spacing: NomadSpacing.xSmall) {
                        Text(fact.label.value(for: locale))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(fact.value.value(for: locale))
                            .font(.headline)
                            .foregroundStyle(Color.tone(tone))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(fact.detail.value(for: locale))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: 130, alignment: .topLeading)
                    .frame(minHeight: 106, alignment: .topLeading)
                    .padding(NomadSpacing.medium)
                    .background(Color.gray.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
    }
}

private struct VisaNoticeBlock: View {
    let notice: VisaArticleNotice
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: NomadSpacing.medium) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.tone(notice.tone))
            VStack(alignment: .leading, spacing: NomadSpacing.xSmall) {
                Text(notice.title.value(for: locale))
                    .font(.headline)
                    .foregroundStyle(Color.tone(notice.tone))
                Text(notice.body.value(for: locale))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(NomadSpacing.large)
        .background(Color.tone(notice.tone).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.tone(notice.tone).opacity(0.22), lineWidth: 1)
        }
    }
}

private struct VisaSectionView: View {
    let section: VisaArticleSection
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: NomadSpacing.medium) {
            Text(section.title.value(for: locale))
                .font(.title2.weight(.bold))

            ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph.value(for: locale))
                    .font(.body)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(section.highlights) { highlight in
                VisaHighlightRow(highlight: highlight)
            }

            ForEach(Array(section.bullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .firstTextBaseline, spacing: NomadSpacing.small) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                    Text(bullet.value(for: locale))
                        .font(.body)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct VisaHighlightRow: View {
    let highlight: VisaHighlight
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: NomadSpacing.xSmall) {
            Text(highlight.label.value(for: locale))
                .font(.headline)
                .foregroundStyle(Color.tone(highlight.tone))
            Text(highlight.detail.value(for: locale))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NomadSpacing.large)
        .background(Color.tone(highlight.tone).opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct VisaSourcesSection: View {
    let sources: [VisaSource]
    let updatedAt: String
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: NomadSpacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "visa.sources.title", locale: locale))
                    .font(.title2.weight(.bold))
                Spacer()
                Text(String.localizedStringWithFormat(String(localized: "visa.sources.updated", locale: locale), updatedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(sources) { source in
                Link(destination: source.url) {
                    HStack(alignment: .top, spacing: NomadSpacing.medium) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                Text(source.title.value(for: locale))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                Text(source.publisher.value(for: locale))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(NomadSpacing.medium)
                    .background(Color.nomadSurface, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
