import SwiftUI

struct CheckInView: View {
    private enum SelectedStat: Hashable {
        case cities, countries, days
    }

    @Environment(UserDataStore.self) private var userData
    @State private var viewModel = CheckInViewModel()
    @State private var selectedStat: SelectedStat?
    @State private var showingCountryList = false
    @State private var visitedCountries: Set<OnboardingView.Country> = []
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    globe
                    Text("checkin.summary")
                        .font(.vastago(18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    stats
                    HStack(alignment: .firstTextBaseline) {
                        Text("checkin.badges.title").font(.vastago(20, weight: .semibold))
                        Spacer()
                        Text(String.localizedStringWithFormat(String(localized: "checkin.badges.progress"), unlockedBadgeCount, viewModel.badges.count)).font(.subheadline).foregroundStyle(.secondary)
                    }
                    badgeGrid
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 110)
            }
            .background(Color.nomadBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingCountryList) {
            VisitedCountriesStep(selection: $visitedCountries) {
                userData.visitedCountryCodes = visitedCountries.map(\.rawValue).sorted()
                showingCountryList = false
            }
            .presentationDetents([.large])
        }
        .onAppear {
            visitedCountries = Set(userData.visitedCountryCodes.map(OnboardingView.Country.init(rawValue:)))
        }
    }

    private var header: some View {
        HStack {
            Text("Nomad Map").font(.vastago(24, weight: .semibold))
            Spacer()
            Button { showingCountryList = true } label: {
                Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.nomadInk)
                .frame(width: 36, height: 36)
                .background(Color.black.opacity(0.045), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("添加去过的国家或地区")
        }
    }

    private var globe: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Color(red: 0.35, green: 0.52, blue: 0.54).opacity(0.18))
                .frame(width: 200, height: 28)
                .blur(radius: 15)
                .opacity(0.8)
                .offset(y: 8)

            NomadGlobeView(showLabels: selectedStat != nil, visitedCountryCodes: userData.visitedCountryCodes)
                .accessibilityLabel("COBE 旅行足迹地球")
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    private var stats: some View {
        return HStack(alignment: .top, spacing: 12) {
            TravelStat(value: 3, label: String(localized: "checkin.stat.cities"), symbol: "building.2.fill", isSelected: selectedStat == .cities) { toggleStat(.cities) }
            TravelStat(value: Set(userData.visitedCountryCodes).count, label: String(localized: "checkin.stat.countries"), symbol: "flag.fill", isSelected: selectedStat == .countries) { toggleStat(.countries) }
            TravelStat(value: 15, label: String(localized: "checkin.stat.days"), symbol: "calendar", isSelected: selectedStat == .days) { toggleStat(.days) }
        }
    }

    private func toggleStat(_ stat: SelectedStat) {
        selectedStat = selectedStat == stat ? nil : stat
    }

    private var badgeGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(viewModel.badges.prefix(4)) { badge in
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: badge.symbol)
                        .font(.title2)
                        .foregroundStyle(userData.isBadgeUnlocked(badge) ? Color.tone(badge.tone) : .secondary)
                    Text(localized(badge.title)).font(.headline)
                    Text("\(badge.rule.threshold) · \(localized(badge.detail))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: 125, alignment: .topLeading)
                .padding(16)
                .background(Color.nomadSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func localized(_ copy: LocalizedCopy) -> String { copy.value(for: locale) }
    private var unlockedBadgeCount: Int { viewModel.badges.filter { userData.isBadgeUnlocked($0) }.count }
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
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(value)")
                        .font(.vastago(17, weight: .bold))
                        .contentTransition(.numericText())
                }
                .foregroundStyle(isSelected ? Color.nomadBlue : Color.nomadInk)

                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.vertical, 12)
            .background(Color.nomadBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? Color.nomadBlue : Color.nomadLavender.opacity(0.72), lineWidth: 0.3)
            }
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
    }
}
