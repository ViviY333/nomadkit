import SwiftUI
import UIKit

struct CheckInView: View {
    private enum SelectedStat: Hashable {
        case cities, countries, coverage

        var globeLabelMode: NomadGlobeLabelMode {
            switch self {
            case .cities: .cities
            case .countries: .countries
            case .coverage: .countries
            }
        }
    }

    @Environment(UserDataStore.self) private var userData
    @Environment(\.locale) private var locale
    @State private var selectedStat: SelectedStat?
    @State private var showingAddPlaces = false
    @State private var addPlacesMode: AddPlacesView.Mode = .manual
    @State private var selectedStamp: SelectedStamp?
    @State private var earnedVisits: [TravelVisit] = []
    @State private var showingBadgeReveal = false
    @State private var showingStampsAfterBadgeReveal = false
    // The star-field globe is the primary passport visual.
    @State private var showingGlobeExplorer = true
    @State private var showingStamps = false

    var body: some View {
        NavigationStack {
            Group {
                if showingGlobeExplorer {
                    immersiveGlobe
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 26) {
                            mapSection
                            if userData.hasRecordedPlaces {
                                stampSection
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 110)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if showingGlobeExplorer {
                    globeHeader
                } else {
                    FixedMainPageHeader { header }
                }
            }
            .background(showingGlobeExplorer ? Color.nomadGlobeBackground : Color.nomadBackground)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.automatic, for: .tabBar)
        }
        .preferredColorScheme(showingGlobeExplorer ? .dark : nil)
        .sheet(isPresented: $showingAddPlaces, onDismiss: presentEarnedVisitsIfNeeded) {
            AddPlacesView(initialMode: addPlacesMode) { visits in
                let recordedIDs = Set(earnedVisits.map(\.id))
                earnedVisits.append(contentsOf: visits.filter { !recordedIDs.contains($0.id) })
            }
        }
        .fullScreenCover(isPresented: $showingBadgeReveal, onDismiss: presentStampsAfterBadgeRevealIfNeeded) {
            BadgeEarnedView(
                visits: earnedVisits,
                onClose: {
                    showingStampsAfterBadgeReveal = false
                    showingBadgeReveal = false
                },
                onViewStamps: {
                    showingStampsAfterBadgeReveal = true
                    showingBadgeReveal = false
                }
            )
        }
        .sheet(isPresented: $showingStamps) {
            StampsSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedStamp) { stamp in
            CountryStampDetailView(code: stamp.id, visitedAt: stamp.visitedAt)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack {
            Text("checkin.placesBeen.title")
                .font(.vastago(24, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            Button { openAddPlaces(mode: .manual) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.nomadInk)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.045), in: Circle())
            }
            .buttonStyle(NomadPlainButtonStyle())
            .accessibilityLabel(appLocalized("checkin.addPlace.accessibility", locale: locale))
            Button { showingStamps = true } label: {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.nomadInk)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.045), in: Circle())
            }
            .buttonStyle(NomadPlainButtonStyle())
            .accessibilityLabel(appLocalized("checkin.stamps.title", locale: locale))
        }
    }

    private var globeHeader: some View {
        HStack {
            Text("checkin.placesBeen.title")
                .font(.vastago(24, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            Button { openAddPlaces(mode: .manual) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.13), in: Circle())
                    .overlay { Circle().stroke(.white.opacity(0.18), lineWidth: 0.6) }
            }
            .buttonStyle(NomadPlainButtonStyle())
            .accessibilityLabel(appLocalized("checkin.addPlace.accessibility", locale: locale))
            Button { showingStamps = true } label: {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.13), in: Circle())
                    .overlay { Circle().stroke(.white.opacity(0.18), lineWidth: 0.6) }
            }
            .buttonStyle(NomadPlainButtonStyle())
            .accessibilityLabel(appLocalized("checkin.stamps.title", locale: locale))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .background(Color.nomadGlobeBackground.opacity(0.92))
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [Color.nomadGlobeBackground.opacity(0.9), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 24)
            .offset(y: 24)
            .allowsHitTesting(false)
        }
    }

    private var immersiveGlobe: some View {
        ZStack {
            Color.nomadGlobeBackground.ignoresSafeArea()
                NomadGlobeGLView(
                showLabels: true,
                visits: userData.visits,
                localeIdentifier: locale.identifier,
                labelMode: selectedStat?.globeLabelMode ?? .none
            )
                .ignoresSafeArea()
                .accessibilityLabel(appLocalized("checkin.globe.accessibility", locale: locale))

            VStack {
                Spacer()
                globeStats
                    .padding(.horizontal, 20)
                    .padding(.bottom, 82)
            }
        }
    }

    private var globeStats: some View {
        HStack(alignment: .top, spacing: 12) {
            GlobeTravelStat(
                value: userData.travelStats.countryCount,
                label: "checkin.stat.countries",
                symbol: "flag.fill",
                isSelected: selectedStat == .countries
            ) { toggleStat(.countries) }
            GlobeTravelStat(
                value: userData.travelStats.worldCoveragePercent,
                suffix: "%",
                label: "checkin.stat.coverage",
                symbol: "globe.europe.africa.fill",
                isSelected: selectedStat == .coverage
            ) { toggleStat(.coverage) }
        }
        .sensoryFeedback(.selection, trigger: selectedStat)
    }

    private var mapSection: some View {
        Group {
            if userData.hasRecordedPlaces {
                VStack(spacing: 12) {
                    globeSurface
                            .accessibilityLabel(appLocalized("checkin.globe.accessibility", locale: locale))
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)

                    stats
                        .padding(.horizontal, 8)
                }
            } else {
                GeometryReader { proxy in
                    let globeSize = min(proxy.size.width, 390)

                    ZStack(alignment: .top) {
                        globeSurface
                            .frame(width: globeSize, height: globeSize)

                        if !showingGlobeExplorer {
                            VStack(spacing: 10) {
                                Text(appLocalized("checkin.headline", locale: locale))
                                    .font(.vastago(18, weight: .semibold))
                                    .multilineTextAlignment(.center)
                                HStack(spacing: 8) {
                                    Button { openAddPlaces(mode: .manual) } label: {
                                        Label(appLocalized("addplaces.mode.manual", locale: locale), systemImage: "plus.circle.fill")
                                            .font(.caption.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 38)
                                            .background(Color.nomadInk, in: Capsule())
                                            .foregroundStyle(.white)
                                    }
                                    Button { openAddPlaces(mode: .photos) } label: {
                                        Label(appLocalized("addplaces.photos.choose", locale: locale), systemImage: "photo.on.rectangle.angled")
                                            .font(.caption.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 38)
                                            .background(Color.black.opacity(0.12), in: Capsule())
                                            .foregroundStyle(Color.nomadInk)
                                    }
                                }
                            }
                            .padding(14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .buttonStyle(NomadPlainButtonStyle())
                            .accessibilityHint(locale.identifier.hasPrefix("zh") ? "从相册扫描或手动添加去过的地点" : "Scan photos or add visited places manually")
                            .padding(.horizontal, 18)
                            .padding(.top, globeSize * 0.36)
                            .zIndex(1)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                .frame(height: 336)
            }
        }
    }

    @ViewBuilder
    private var globeSurface: some View {
        NomadGlobeGLView(
            showLabels: true,
            visits: userData.visits,
            localeIdentifier: locale.identifier,
            labelMode: selectedStat?.globeLabelMode ?? .none
        )
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: 12) {
            TravelStat(value: userData.travelStats.countryCount, label: "checkin.stat.countries", symbol: "flag.fill", isSelected: selectedStat == .countries) { toggleStat(.countries) }
            TravelStat(value: userData.travelStats.worldCoveragePercent, suffix: "%", label: "checkin.stat.coverage", symbol: "globe.europe.africa.fill", isSelected: selectedStat == .coverage) { toggleStat(.coverage) }
        }
    }

    private var stampSection: some View {
        let countries = userData.recordedCountryCodes
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("checkin.stamps.title").font(.vastago(20, weight: .semibold))
                Spacer()
                Text(String.localizedStringWithFormat(appLocalized("checkin.stamps.count", locale: locale), countries.count))
                    .font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], spacing: 22) {
                ForEach(countries, id: \.self) { code in
                    let visitedAt = userData.visits
                        .filter { $0.countryID == code }
                        .max { $0.checkedInAt < $1.checkedInAt }?.checkedInAt ?? .now
                    CountryStampView(code: code, visitedAt: visitedAt, locale: locale) {
                        selectedStamp = SelectedStamp(id: code, visitedAt: visitedAt)
                    }
                }
            }
        }
    }

    private func toggleStat(_ stat: SelectedStat) { selectedStat = selectedStat == stat ? nil : stat }

    private func openAddPlaces(mode: AddPlacesView.Mode) {
        earnedVisits = []
        showingStampsAfterBadgeReveal = false
        addPlacesMode = mode
        showingAddPlaces = true
    }

    private func presentEarnedVisitsIfNeeded() {
        guard !earnedVisits.isEmpty else { return }
        showingBadgeReveal = true
    }

    private func presentStampsAfterBadgeRevealIfNeeded() {
        guard showingStampsAfterBadgeReveal else { return }
        showingStampsAfterBadgeReveal = false
        showingStamps = true
    }
}

private struct StampsSheetView: View {
    @Environment(UserDataStore.self) private var userData
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStamp: SelectedStamp?

    private var countryCodes: [String] { userData.recordedCountryCodes }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if countryCodes.isEmpty {
                    ContentUnavailableView(
                        appLocalized("checkin.stamps.empty", locale: locale),
                        systemImage: "checkmark.seal",
                        description: Text(appLocalized("checkin.stamps.emptyDetail", locale: locale))
                    )
                    .padding(.top, 50)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], spacing: 22) {
                        ForEach(countryCodes, id: \.self) { code in
                            let visitedAt = userData.visits
                                .filter { $0.countryID == code }
                                .max { $0.checkedInAt < $1.checkedInAt }?.checkedInAt ?? .now
                            CountryStampView(code: code, visitedAt: visitedAt, locale: locale) {
                                selectedStamp = SelectedStamp(id: code, visitedAt: visitedAt)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
            .background(Color.nomadBackground)
            .navigationTitle(appLocalized("checkin.stamps.title", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appLocalized("common.done", locale: locale)) { dismiss() }
                }
            }
        }
        .sheet(item: $selectedStamp) { stamp in
            CountryStampDetailView(code: stamp.id, visitedAt: stamp.visitedAt)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct SelectedStamp: Identifiable {
    let id: String
    let visitedAt: Date
}

private struct BadgeEarnedView: View {
    @Environment(\.locale) private var locale
    let visits: [TravelVisit]
    let onClose: () -> Void
    let onViewStamps: () -> Void

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 40, height: 40)
                    }
                    .accessibilityLabel(appLocalized("common.close", locale: locale))
                    Spacer()
                    Button(action: onViewStamps) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 40, height: 40)
                    }
                    .accessibilityLabel(appLocalized("checkin.stamps.title", locale: locale))
                }
                .foregroundStyle(Color.nomadInk)
                .padding(.horizontal, 18)
                .padding(.top, 10)

                Spacer(minLength: 18)

                Text(appLocalized("checkin.badgeEarned.title", locale: locale))
                    .font(.vastago(28, weight: .semibold))
                    .foregroundStyle(Color.nomadInk)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 18) {
                        ForEach(visits) { visit in
                            VStack(spacing: 14) {
                                if let image = countryStampImage(for: visit.countryID) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 220, height: 220)
                                } else {
                                    GenericCountryStampView(code: visit.countryID, visitedAt: visit.checkedInAt)
                                        .frame(width: 220, height: 220)
                                }
                                Text(visit.countryName.value(for: locale))
                                    .font(.vastago(24, weight: .semibold))
                                    .foregroundStyle(Color.nomadInk)
                                    .lineLimit(1)
                                Text(visit.checkedInAt.formatted(.dateTime.year().month(.abbreviated).day().locale(locale)))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 260)
                        }
                    }
                    .padding(.horizontal, max(24, UIScreen.main.bounds.width / 2 - 130))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)

                Spacer()
            }
        }
        .preferredColorScheme(.light)
    }
}

private struct CountryStampView: View {
    let code: String
    let visitedAt: Date
    let locale: Locale
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let image = countryStampImage(for: code) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 116)
                } else {
                    GenericCountryStampView(code: code, visitedAt: visitedAt)
                        .frame(height: 116)
                }
                Text(CountryCatalog.name(for: code).value(for: locale))
                    .font(.vastago(17, weight: .semibold))
                    .foregroundStyle(Color.nomadInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(visitedAt, format: .dateTime.year().month(.abbreviated).day().locale(locale))
                    .font(.vastago(12, weight: .medium))
                    .foregroundStyle(Color.nomadInk.opacity(0.5))
            }
        }
        .buttonStyle(NomadPlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

private struct CountryStampDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    let code: String
    let visitedAt: Date
    @State private var shineOffset: CGFloat = -1.4

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(CountryCatalog.name(for: code).value(for: locale))
                            .font(.vastago(24, weight: .semibold))
                        Text("checkin.stamps.detailTitle")
                            .font(.vastago(13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(NomadPlainButtonStyle())
                        .accessibilityLabel(appLocalized("common.close", locale: locale))
                }
                .padding(.horizontal, 22)
                ZStack {
                    if let image = countryStampImage(for: code) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: 290, maxHeight: 190)
                    } else {
                        GenericCountryStampView(code: code, visitedAt: visitedAt)
                            .frame(width: 190, height: 190)
                    }
                    if !reduceMotion {
                        LinearGradient(colors: [.clear, .white.opacity(0.95), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(width: 40, height: 220)
                            .rotationEffect(.degrees(28))
                            .offset(x: shineOffset * 300)
                            .blendMode(.screen)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                VStack(spacing: 3) {
                    Text("checkin.stamps.recordedOn")
                        .font(.vastago(12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(visitedAt, format: .dateTime.year().month(.wide).day().locale(locale))
                        .font(.vastago(17, weight: .semibold))
                        .foregroundStyle(Color.nomadInk)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.7)) { shineOffset = 1.4 }
        }
    }
}

private struct GenericCountryStampView: View {
    let code: String
    let visitedAt: Date

    private var year: String {
        visitedAt.formatted(.dateTime.year())
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .stroke(Color.nomadInk.opacity(0.7), lineWidth: max(2, size * 0.035))
                Circle()
                    .stroke(Color.nomadInk.opacity(0.55), lineWidth: max(1, size * 0.012))
                    .padding(size * 0.07)
                VStack(spacing: size * 0.035) {
                    Text(code.uppercased())
                        .font(.vastago(size * 0.18, weight: .bold))
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: size * 0.26, weight: .regular))
                    Text(year)
                        .font(.vastago(size * 0.1, weight: .semibold))
                }
                .foregroundStyle(Color.nomadInk.opacity(0.72))
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-4))
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .accessibilityHidden(true)
    }
}

private func countryStampImage(for code: String) -> UIImage? {
    guard let assetName = CountryCatalog.stampAsset(for: code) else { return nil }
    return UIImage(named: assetName)
}

private struct TravelStat: View {
    let value: Int
    var suffix: String = ""
    let label: LocalizedStringKey
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
                    Text("\(value)\(suffix)").font(.vastago(17, weight: .bold)).contentTransition(.numericText())
                }
                .foregroundStyle(isSelected ? Color.nomadBlue : Color.nomadInk)
                Text(label).font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(2).minimumScaleFactor(0.86)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.vertical, 12)
            .background(Color.nomadBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(isSelected ? Color.nomadBlue : Color.nomadLavender.opacity(0.72), lineWidth: 0.3) }
        }
        .buttonStyle(NomadPlainButtonStyle())
    }
}

private struct GlobeTravelStat: View {
    let value: Int
    var suffix: String = ""
    let label: LocalizedStringKey
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(value)\(suffix)")
                        .font(.vastago(17, weight: .bold))
                        .contentTransition(.numericText())
                }
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(isSelected ? 0.86 : 0.62))
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.94))
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.vertical, 12)
            .background(.black.opacity(isSelected ? 0.68 : 0.42), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(isSelected ? 0.72 : 0.18), lineWidth: isSelected ? 1.2 : 0.5)
            }
        }
        .buttonStyle(NomadPlainButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}
