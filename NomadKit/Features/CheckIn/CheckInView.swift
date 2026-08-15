import SwiftUI

struct CheckInView: View {
    private enum SelectedStat: Hashable { case cities, countries, days }

    @Environment(UserDataStore.self) private var userData
    @State private var viewModel = CheckInViewModel()
    @State private var selectedStat: SelectedStat?
    @State private var showingAddPlaces = false
    @State private var selectedBadge: BadgeDefinition?
    @State private var selectedStamp: SelectedStamp?
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    mapSection
                    if userData.hasRecordedPlaces {
                        Text("checkin.summary")
                            .font(.vastago(18, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                        stats
                        stampSection
                    }
                    badgeSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 110)
            }
            .background(Color.nomadBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingAddPlaces) { AddPlacesView() }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge, isUnlocked: userData.isBadgeUnlocked(badge), locale: locale)
        }
        .sheet(item: $selectedStamp) { stamp in
            CountryStampDetailView(code: stamp.id)
        }
    }

    private var header: some View {
        HStack {
            Text("Nomad Map").font(.vastago(24, weight: .semibold))
            Spacer()
            Button { showingAddPlaces = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.nomadInk)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.045), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("添加去过的地点")
        }
    }

    private var mapSection: some View {
        Group {
            if userData.hasRecordedPlaces {
                NomadGlobeView(showLabels: selectedStat != nil, visits: userData.visits)
                    .accessibilityLabel("COBE 旅行足迹地球")
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            } else {
                VStack(spacing: 2) {
                    NomadGlobeView(visits: [])
                        .frame(maxWidth: .infinity)
                        .frame(height: 210)
                        .clipped()
                    Button { showingAddPlaces = true } label: {
                        Label("Add places you've been", systemImage: "plus.circle.fill")
                            .font(.vastago(15, weight: .semibold))
                            .foregroundStyle(Color.nomadInk)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Color.nomadSurface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("从相册扫描或手动添加去过的地点")
                }
            }
        }
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: 12) {
            TravelStat(value: userData.travelStats.cityCount, label: String(localized: "checkin.stat.cities"), symbol: "building.2.fill", isSelected: selectedStat == .cities) { toggleStat(.cities) }
            TravelStat(value: userData.travelStats.countryCount, label: String(localized: "checkin.stat.countries"), symbol: "flag.fill", isSelected: selectedStat == .countries) { toggleStat(.countries) }
            TravelStat(value: userData.travelStats.totalDays, label: String(localized: "checkin.stat.days"), symbol: "calendar", isSelected: selectedStat == .days) { toggleStat(.days) }
        }
    }

    private var stampSection: some View {
        let countries = userData.recordedCountryCodes
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Passport stamps").font(.vastago(20, weight: .semibold))
                Spacer()
                Text("\(countries.count) countries").font(.caption).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(countries, id: \.self) { code in
                        CountryStampView(code: code) { selectedStamp = SelectedStamp(id: code) }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("checkin.badges.title").font(.vastago(20, weight: .semibold))
                Spacer()
                Text(String.localizedStringWithFormat(String(localized: "checkin.badges.progress"), unlockedBadgeCount, viewModel.badges.count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.badges) { badge in
                    Button { selectedBadge = badge } label: {
                        BadgeCard(badge: badge, isUnlocked: userData.isBadgeUnlocked(badge), locale: locale)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggleStat(_ stat: SelectedStat) { selectedStat = selectedStat == stat ? nil : stat }
    private var unlockedBadgeCount: Int { viewModel.badges.filter { userData.isBadgeUnlocked($0) }.count }
}

private struct SelectedStamp: Identifiable { let id: String }

private struct CountryStampView: View {
    let code: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
            if let asset = CountryCatalog.stampAsset(for: code) {
                Image(asset).resizable().scaledToFit().frame(width: 132, height: 92)
            } else {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.nomadInk.opacity(0.5))
                    .frame(width: 132, height: 92)
            }
            Text(CountryCatalog.name(for: code).value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.nomadInk)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 132)
    }
}

private struct CountryStampDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let code: String
    @State private var shineOffset: CGFloat = -1.4

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 22) {
                HStack {
                    Text(CountryCatalog.name(for: code).value).font(.vastago(20, weight: .semibold))
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("关闭印章详情")
                }
                .padding(.horizontal, 22)
                Spacer()
                ZStack {
                    if let asset = CountryCatalog.stampAsset(for: code) {
                        Image(asset).resizable().scaledToFit().frame(maxWidth: 330, maxHeight: 300)
                    } else {
                        Image(systemName: "globe.europe.africa.fill")
                            .font(.system(size: 90, weight: .medium))
                            .foregroundStyle(Color.nomadInk.opacity(0.45))
                    }
                    if !reduceMotion {
                        LinearGradient(colors: [.clear, .white.opacity(0.95), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(width: 44, height: 360)
                            .rotationEffect(.degrees(28))
                            .offset(x: shineOffset * 300)
                            .blendMode(.screen)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 300)
                Spacer()
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.7)) { shineOffset = 1.4 }
        }
    }
}

private struct BadgeCard: View {
    let badge: BadgeDefinition
    let isUnlocked: Bool
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: badge.symbol)
                .font(.title2)
                .foregroundStyle(isUnlocked ? Color.tone(badge.tone) : .secondary)
            Text(badge.title.value(for: locale)).font(.headline)
            Text("\(badge.rule.threshold) · \(badge.detail.value(for: locale))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 125, alignment: .topLeading)
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.nomadLavender.opacity(0.34), lineWidth: 0.5) }
    }
}

private struct BadgeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let badge: BadgeDefinition
    let isUnlocked: Bool
    let locale: Locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shineOffset: CGFloat = -1.4

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                        .font(.system(size: 16, weight: .semibold))
                        .accessibilityLabel("关闭徽章详情")
                }
                .padding(.horizontal, 22)
                Spacer()
                ZStack {
                    Circle().fill(Color.tone(badge.tone).opacity(isUnlocked ? 0.14 : 0.06)).frame(width: 230, height: 230)
                    Image(systemName: badge.symbol)
                        .font(.system(size: 86, weight: .medium))
                        .foregroundStyle(isUnlocked ? Color.tone(badge.tone) : .secondary.opacity(0.45))
                    if isUnlocked && !reduceMotion {
                        LinearGradient(colors: [.clear, .white.opacity(0.95), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(width: 42, height: 260)
                            .rotationEffect(.degrees(28))
                            .offset(x: shineOffset * 260)
                            .blendMode(.screen)
                            .allowsHitTesting(false)
                    }
                }
                .clipShape(Circle())
                Text(badge.title.value(for: locale)).font(.vastago(28, weight: .semibold)).foregroundStyle(Color.nomadInk)
                Text(badge.detail.value(for: locale)).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40)
                Text(isUnlocked ? "已解锁" : "继续旅行来解锁").font(.subheadline.weight(.semibold)).foregroundStyle(isUnlocked ? Color.tone(badge.tone) : .secondary)
                Spacer()
            }
        }
        .onAppear {
            guard isUnlocked, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.7)) { shineOffset = 1.4 }
        }
    }
}

private struct TravelStat: View {
    let value: Int
    let label: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
                    Text("\(value)").font(.vastago(17, weight: .bold)).contentTransition(.numericText())
                }
                .foregroundStyle(isSelected ? Color.nomadBlue : Color.nomadInk)
                Text(label).font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(2).minimumScaleFactor(0.86)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.vertical, 12)
            .background(Color.nomadBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(isSelected ? Color.nomadBlue : Color.nomadLavender.opacity(0.72), lineWidth: 0.3) }
        }
        .buttonStyle(.plain)
    }
}
