import SwiftUI

struct VisaLibraryView: View {
    @State private var viewModel = VisaLibraryViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if viewModel.articles.isEmpty, let error = viewModel.errorMessage {
                ContentUnavailableView(
                    appLocalized("visa.loadError.title", locale: locale),
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
        .navigationTitle(locale.identifier.hasPrefix("zh") ? "数字游民签证" : "Digital Nomad Visas")
        .navigationBarTitleDisplayMode(.inline)
        .nomadInteractiveBackGesture()
    }
}

private struct VisaLibraryHeader: View {
    @Environment(\.locale) private var locale
    var body: some View {
        Text(appLocalized("visa.header.title", locale: locale))
            .font(.system(.title3, design: .rounded, weight: .bold))
            .fixedSize(horizontal: false, vertical: true)
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
                Label(String.localizedStringWithFormat(appLocalized("visa.readTime", locale: locale), article.readTimeMinutes), systemImage: "clock")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 20)
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
            appLocalized("visa.disclaimer", locale: locale),
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
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @State private var showsAssessmentPaywall = false
    @State private var showsAssessment = false
    @State private var assessmentResult: VisaAssessmentResult?
    @State private var hasUsedFreeAssessment = UserDefaults.standard.bool(forKey: "visa.assessment.freeUsed")

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: NomadSpacing.xLarge) {
                VisaArticleHero(article: article)
                VisaAssessmentEntryCard(article: article, hasResult: assessmentResult != nil, hasUsedFreeAssessment: hasUsedFreeAssessment, hasProAccess: subscriptionStore.hasProAccess) {
                    if subscriptionStore.hasProAccess || !hasUsedFreeAssessment {
                        showsAssessment = true
                    } else {
                        showsAssessmentPaywall = true
                    }
                }
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
        .nomadInteractiveBackGesture()
        .onAppear {
            if assessmentResult == nil,
               let data = UserDefaults.standard.data(forKey: "visa.assessment.\(article.countryCode)"),
               let saved = try? JSONDecoder().decode(VisaAssessmentResult.self, from: data) {
                assessmentResult = saved
            }
        }
        .sheet(isPresented: $showsAssessmentPaywall) {
            SubscriptionPaywallView(entryPoint: .visaAssessment) {
                showsAssessmentPaywall = false
            }
        }
        .sheet(isPresented: $showsAssessment) {
            NavigationStack {
                VisaAssessmentView(article: article) { result in
                    assessmentResult = result
                    if !subscriptionStore.hasProAccess {
                        UserDefaults.standard.set(true, forKey: "visa.assessment.freeUsed")
                        hasUsedFreeAssessment = true
                    }
                }
            }
        }
    }
}

private struct VisaAssessmentEntryCard: View {
    let article: VisaArticle
    let hasResult: Bool
    let hasUsedFreeAssessment: Bool
    let hasProAccess: Bool
    let action: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            HStack(spacing: NomadSpacing.medium) {
                Image(systemName: "checklist.checked")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.tone(article.tone))
                    .frame(width: 46, height: 46)
                    .background(Color.tone(article.tone).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(hasResult ? (locale.identifier.hasPrefix("zh") ? "查看最近测试结果" : "View latest readiness result") : (locale.identifier.hasPrefix("zh") ? "签证准备度测试" : "Visa readiness test"))
                            .font(.headline)
                        if !hasResult && hasUsedFreeAssessment && !hasProAccess { Text("PRO")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.nomadInk, in: Capsule())
                            .foregroundStyle(.white)
                        }
                    }
                    Text(hasResult ? (locale.identifier.hasPrefix("zh") ? "基于最近一次测试结果。" : "Based on your latest assessment.") : (locale.identifier.hasPrefix("zh") ? "回答 5 个问题，查看你的准备度和材料缺口。" : "Answer 5 questions to see your readiness and missing documents."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(NomadSpacing.large)
            .background(Color.nomadSurface, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableScaleButtonStyle())
        .accessibilityIdentifier("visa.assessment.entry")
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
                Label(String.localizedStringWithFormat(appLocalized("visa.readTime", locale: locale), article.readTimeMinutes), systemImage: "clock")
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
                Text(appLocalized("visa.sources.title", locale: locale))
                    .font(.title2.weight(.bold))
                Spacer()
                Text(String.localizedStringWithFormat(appLocalized("visa.sources.updated", locale: locale), updatedAt))
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
