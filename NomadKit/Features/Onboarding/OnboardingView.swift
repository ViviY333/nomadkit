import SwiftUI
import UIKit

private func onboardingString(_ key: String) -> String {
    NSLocalizedString(key, tableName: "Onboarding", bundle: .main, comment: "")
}

private enum OnboardingLayout {
    static let sectionSpacing: CGFloat = 54
    static let chromeTop: CGFloat = 20
    static let chromeHeight: CGFloat = 36
    static let titleTop: CGFloat = chromeTop + chromeHeight + sectionSpacing
    static let horizontalPadding: CGFloat = 30
    static let buttonBottom: CGFloat = 6
}

struct OnboardingView: View {
    @Environment(UserDataStore.self) private var userData

    @State private var step: Step = ProcessInfo.processInfo.arguments.contains("-onboarding-location") ? .currentPlace : .journey
    @State private var history: [Step] = []
    @State private var stage: JourneyStage = .traveling
    @State private var destinations: Set<Country> = []
    @State private var visitedCountries: Set<Country> = []
    @State private var components: Set<KitTool> = [.visa, .checklist]
    @State private var stayUntil = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    @State private var stayStartedAt = Date.now
    @State private var useStayDate = false
    @State private var departureDate = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now

    private enum Step: Hashable {
        case journey, destination, currentPlace, stayUntil, departureDate, tools, visited, ready
    }

    fileprivate enum JourneyStage: String, CaseIterable, Hashable {
        case traveling, preparing, notTraveling

        var title: String {
            switch self {
            case .preparing: onboardingString("journey.preparing")
            case .notTraveling: onboardingString("journey.notTraveling")
            case .traveling: onboardingString("journey.traveling")
            }
        }

        var symbol: String {
            switch self {
            case .preparing: "airplane.departure"
            case .notTraveling: "globe.asia.australia"
            case .traveling: "location.fill"
            }
        }

        var detail: String {
            switch self {
            case .preparing: "先把下一站需要的事准备好"
            case .notTraveling: "记录足迹，也慢慢看看下一站"
            case .traveling: "把当地生活和工作安排明白"
            }
        }
    }

    struct Country: RawRepresentable, CaseIterable, Hashable, Identifiable {
        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue.uppercased()
        }

        var id: String { rawValue }

        static let allCases: [Country] = Locale.Region.isoRegions
            .map(\.identifier)
            .filter { $0.count == 2 }
            .map(Country.init(rawValue:))
            .sorted { $0.englishName < $1.englishName }

        static let australia = Country(rawValue: "AU")
        static let china = Country(rawValue: "CN")
        static let hongKong = Country(rawValue: "HK")
        static let indonesia = Country(rawValue: "ID")
        static let italy = Country(rawValue: "IT")
        static let japan = Country(rawValue: "JP")
        static let malaysia = Country(rawValue: "MY")
        static let portugal = Country(rawValue: "PT")
        static let singapore = Country(rawValue: "SG")
        static let southKorea = Country(rawValue: "KR")
        static let spain = Country(rawValue: "ES")
        static let taiwan = Country(rawValue: "TW")
        static let thailand = Country(rawValue: "TH")
        static let unitedArabEmirates = Country(rawValue: "AE")
        static let unitedKingdom = Country(rawValue: "GB")
        static let unitedStates = Country(rawValue: "US")
        static let vietnam = Country(rawValue: "VN")

        var title: String {
            Locale.autoupdatingCurrent.localizedString(forRegionCode: rawValue) ?? englishName
        }

        var englishName: String {
            Locale(identifier: "en_US").localizedString(forRegionCode: rawValue) ?? rawValue
        }

        var flag: String {
            rawValue.unicodeScalars.compactMap { scalar in
                UnicodeScalar(127_397 + scalar.value).map(String.init)
            }.joined()
        }

        var initial: String { String(englishName.prefix(1)) }

        static let digitalNomadFavorites: [Country] = [
            .thailand, .japan, .singapore, .indonesia, .malaysia,
            .vietnam, Country(rawValue: "MX"), Country(rawValue: "CO"),
            .unitedStates, .china
        ]
    }

    fileprivate enum KitTool: String, CaseIterable, Hashable {
        case visa, exchange, coworking, connectivity, checklist, insurance, weather

        var title: String {
            switch self {
            case .visa: onboardingString("tool.visa")
            case .exchange: onboardingString("tool.exchange")
            case .coworking: onboardingString("tool.coworking")
            case .connectivity: onboardingString("tool.connectivity")
            case .checklist: onboardingString("tool.checklist")
            case .insurance: onboardingString("tool.insurance")
            case .weather: onboardingString("tool.weather")
            }
        }

        var symbol: String {
            switch self {
            case .visa: "calendar.badge.clock"; case .exchange: "arrow.left.arrow.right"; case .coworking: "building.2"; case .connectivity: "wifi"; case .checklist: "checklist"; case .insurance: "cross.case"; case .weather: "cloud.sun"
            }
        }

        var tint: Color {
            switch self {
            case .visa: .nomadBlue
            case .exchange: .nomadYellow
            case .coworking: .nomadGreen
            case .connectivity: .nomadInk
            case .checklist: .nomadPink
            case .insurance: .nomadLavender
            case .weather: .nomadYellow
            }
        }
    }

    var body: some View {
        ZStack {
            OnboardingBackdrop()
            currentStep
                .overlay(alignment: .top) {
                    OnboardingStepChrome(
                        canGoBack: !history.isEmpty,
                        activeIndex: indicatorIndex,
                        backAction: goBack,
                        skipAction: skipAction
                    )
                    .padding(.horizontal, 36)
                    .padding(.top, OnboardingLayout.chromeTop)
                }
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder private var currentStep: some View {
        switch step {
        case .journey:
            JourneyStep(selection: $stage, continueAction: advance)
        case .destination:
            CountryPickerStep(
                title: onboardingString("destination.title"),
                subtitle: "",
                selection: $destinations,
                primaryTitle: onboardingString("continue"),
                allowSkip: stage == .notTraveling,
                continueAction: advance
            )
        case .currentPlace:
            CurrentPlaceStep(continueAction: advance)
        case .stayUntil:
            StayUntilStep(startDate: $stayStartedAt, endDate: $stayUntil, isEnabled: $useStayDate, continueAction: advance)
        case .departureDate:
            DepartureDateStep(date: $departureDate, continueAction: advance)
        case .tools:
            ToolsStep(selection: $components, continueAction: advance)
        case .visited:
            VisitedCountriesStep(selection: $visitedCountries, continueAction: advance)
        case .ready:
            KitReadyStep(stage: stage, destination: destinations.sorted { $0.englishName < $1.englishName }.first, visitedCount: visitedCountries.count, action: finish)
        }
    }

    private var indicatorIndex: Int {
        let route = routeSteps
        guard let index = route.firstIndex(of: step), route.count > 1 else { return 0 }
        return min(Int((Double(index) / Double(route.count - 1) * 2).rounded()), 2)
    }

    private var routeSteps: [Step] {
        switch stage {
        case .traveling: [.journey, .currentPlace, .stayUntil, .tools, .ready]
        case .preparing: [.journey, .currentPlace, .destination, .departureDate, .tools, .ready]
        case .notTraveling: [.journey, .currentPlace, .destination, .tools, .ready]
        }
    }

    private func advance() {
        let next: Step
        switch step {
        case .journey:
            next = .currentPlace
        case .currentPlace:
            switch stage {
            case .traveling: next = .stayUntil
            case .preparing: next = .destination
            case .notTraveling: next = .destination
            }
        case .destination:
            next = stage == .preparing ? .departureDate : .tools
        case .stayUntil:
            next = .tools
        case .departureDate:
            next = .tools
        case .tools:
            next = .ready
        case .visited:
            next = .ready
        case .ready:
            return
        }
        withAnimation(.smooth(duration: 0.28)) {
            history.append(step)
            step = next
        }
    }

    private func goBack() {
        guard let previous = history.popLast() else { return }
        withAnimation(.smooth(duration: 0.25)) { step = previous }
    }

    private var skipAction: (() -> Void)? {
        switch step {
        case .journey, .currentPlace, .visited:
            { performSkip() }
        default:
            nil
        }
    }

    private func performSkip() {
        switch step {
        case .journey:
            stage = .notTraveling
            advance()
        case .currentPlace:
            advance()
        case .visited:
            advance()
        default:
            break
        }
    }

    private func finish() {
        guard step == .ready else { return }
        userData.journeyStageID = stage.rawValue
        userData.plannedCountryCodes = destinations.map(\.rawValue).sorted()
        if !visitedCountries.isEmpty {
            userData.recordVisitedCountries(visitedCountries.map(\.rawValue))
        }
        userData.preferredComponentIDs = components.map(\.rawValue).sorted()
        userData.allowedStayUntil = useStayDate ? stayUntil : nil
        userData.currentStayStartedAt = useStayDate ? stayStartedAt : nil

        userData.onboardingCompleted = true
    }

}

private struct OnboardingStepChrome: View {
    let canGoBack: Bool
    let activeIndex: Int
    let backAction: () -> Void
    let skipAction: (() -> Void)?

    var body: some View {
        ZStack {
            HStack {
                if canGoBack {
                    Button(action: backAction) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableScaleButtonStyle())
                    .accessibilityLabel(onboardingString("back"))
                }
                Spacer()
            }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                            .fill(Color.nomadInk.opacity(index == activeIndex ? 0.75 : 0.14))
                        .frame(width: index == activeIndex ? 26 : 18, height: 7)
                }
            }

            HStack {
                Spacer()
                if let skipAction {
                    Button(onboardingString("skip"), action: skipAction)
                        .font(.onboarding(14, weight: .semibold, relativeTo: .subheadline))
                            .foregroundStyle(Color.nomadInk.opacity(0.42))
                        .contentShape(Rectangle())
                }
            }
        }
        .frame(height: OnboardingLayout.chromeHeight)
    }
}

private struct JourneyStep: View {
    @Binding var selection: OnboardingView.JourneyStage
    let continueAction: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Text(onboardingString("journey.title"))
                    .font(.onboarding(28, weight: .semibold, relativeTo: .title))
                    .multilineTextAlignment(.center)
                    .lineSpacing(-1)
                }
                .padding(.top, OnboardingLayout.titleTop)
                .padding(.bottom, OnboardingLayout.sectionSpacing)

                GeometryReader { proxy in
                    let scale = min(proxy.size.width / 440, 1.08)

                    ZStack(alignment: .top) {
                        Image("OnboardingStageArc")
                            .resizable()
                            .frame(width: 447.04, height: 107.95)
                            .position(x: 220, y: 53.98)

                        ForEach(OnboardingView.JourneyStage.allCases, id: \.self) { stage in
                            let relativeIndex = relativeIndex(for: stage)
                            stageTag(stage, relativeIndex: relativeIndex)
                                .position(
                                    x: tagCenterX(relativeIndex) + dragOffset,
                                    y: relativeIndex == 0 ? 247 : 159
                                )
                                .zIndex(relativeIndex == 0 ? 2 : 1)
                        }
                    }
                    .frame(width: 440, height: 487, alignment: .top)
                    .scaleEffect(scale, anchor: .top)
                    .frame(width: proxy.size.width, height: 487 * scale, alignment: .top)
                    .contentShape(Rectangle())
                    .highPriorityGesture(stageDrag)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(onboardingString("journey.accessibility"))
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: moveSelection(by: 1)
                        case .decrement: moveSelection(by: -1)
                        @unknown default: break
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 74)

            Button(onboardingString("continue"), action: continueAction)
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .frame(maxWidth: 337)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
        .padding(.bottom, OnboardingLayout.buttonBottom)
    }

    private var stageDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragOffset) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.width
                if projected < -42 { moveSelection(by: 1) }
                else if projected > 42 { moveSelection(by: -1) }
            }
    }

    private func relativeIndex(for stage: OnboardingView.JourneyStage) -> Int {
        let stages = OnboardingView.JourneyStage.allCases
        let selectedIndex = stages.firstIndex(of: selection) ?? 0
        let stageIndex = stages.firstIndex(of: stage) ?? 0
        var relativeIndex = stageIndex - selectedIndex
        if relativeIndex > 1 { relativeIndex -= stages.count }
        if relativeIndex < -1 { relativeIndex += stages.count }
        return relativeIndex
    }

    private func tagCenterX(_ relativeIndex: Int) -> CGFloat {
        switch relativeIndex {
        case -1: 86
        case 1: 354
        default: 220
        }
    }

    private func moveSelection(by offset: Int) {
        let stages = OnboardingView.JourneyStage.allCases
        let current = stages.firstIndex(of: selection) ?? 0
        let next = (current + offset + stages.count) % stages.count
        guard next != current else { return }
        if reduceMotion { selection = stages[next] }
        else { withAnimation(.smooth(duration: 0.26)) { selection = stages[next] } }
    }

    private func stageTag(_ stage: OnboardingView.JourneyStage, relativeIndex: Int) -> some View {
        let isSelected = relativeIndex == 0

        return Button {
            withAnimation(.smooth(duration: 0.2)) { selection = stage }
        } label: {
            ZStack(alignment: .top) {
                stageTagCard(stage, isSelected: isSelected)
                    .offset(y: isSelected ? 17 : 12)

                Image(hookAssetName(relativeIndex))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22.3, height: 30.5)
            }
            .frame(
                width: isSelected ? 244.4 : 137,
                height: isSelected ? 304 : 160,
                alignment: .top
            )
            .rotationEffect(.degrees(isSelected ? 0 : (relativeIndex < 0 ? 10.79 : -10.79)))
            .opacity(isSelected ? 1 : 0.3)
        }
        .buttonStyle(PressableScaleButtonStyle())
        .accessibilityLabel(stage.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func stageTagCard(_ stage: OnboardingView.JourneyStage, isSelected: Bool) -> some View {
        let cardSize = isSelected ? CGSize(width: 244.4, height: 280) : CGSize(width: 112.6, height: 129.1)
        let iconSize: CGFloat = isSelected ? 112 : 51.6
        let cornerRadius: CGFloat = isSelected ? 42.1 : 19.4

        VStack(spacing: isSelected ? 25.5 : 11.7) {
            Image(stageIconAssetName(stage))
                .resizable()
                .scaledToFit()
                .frame(width: isSelected ? 56 : 25.8, height: isSelected ? 56 : 25.8)
                .frame(width: iconSize, height: iconSize)
                .background(Color(red: 0.90, green: 0.96, blue: 1).opacity(0.5), in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color(red: 0.22, green: 0.69, blue: 0.98), lineWidth: isSelected ? 3.5 : 1.6)
                }

            Text(stage.title)
                .font(.onboarding(isSelected ? 24 : 13.5, weight: .medium, relativeTo: isSelected ? .title2 : .caption))
                .foregroundStyle(Color(red: 0.04, green: 0.05, blue: 0.06))
                .multilineTextAlignment(.center)
                .lineLimit(isSelected ? 2 : 1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, isSelected ? 34.2 : 15.8)
        .padding(.horizontal, isSelected ? 34.2 : 15.8)
        .frame(width: cardSize.width, height: cardSize.height, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white)
                .overlay {
                    LinearGradient(
                        colors: [Color(red: 0.60, green: 0.85, blue: 1).opacity(0.16), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white, lineWidth: isSelected ? 5.3 : 2.4)
        }
        .shadow(
            color: Color(red: 0.05, green: 0.20, blue: 0.39).opacity(0.14),
            radius: isSelected ? 40.7 : 18.8,
            x: isSelected ? 7.6 : 3.5,
            y: isSelected ? 7.6 : 3.5
        )
    }

    private func stageIconAssetName(_ stage: OnboardingView.JourneyStage) -> String {
        switch stage {
        case .traveling: "OnboardingStagePuzzle"
        case .preparing: "OnboardingStageBolt"
        case .notTraveling: "OnboardingStageSparkles"
        }
    }

    private func hookAssetName(_ relativeIndex: Int) -> String {
        switch relativeIndex {
        case -1: "OnboardingStageSideHookLeft"
        case 1: "OnboardingStageSideHookRight"
        default: "OnboardingStageHook"
        }
    }
}

private struct CurrentPlaceStep: View {
    @Environment(UserDataStore.self) private var userData
    let continueAction: () -> Void
    @State private var hasRequestedLocation = false
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var selectedCityName: String?
    @State private var locationError: String?
    @FocusState private var searchFocused: Bool
    private let locationService = LocationService()

    private struct PlaceSearchResult: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let flag: String
        let countryCode: String
    }

    private var searchResults: [PlaceSearchResult] {
        OnboardingView.Country.allCases.filter { country in
            let chineseName = Locale(identifier: "zh_Hans").localizedString(forRegionCode: country.rawValue) ?? ""
            return searchText.isEmpty
                || country.title.localizedCaseInsensitiveContains(searchText)
                || country.englishName.localizedCaseInsensitiveContains(searchText)
                || chineseName.localizedCaseInsensitiveContains(searchText)
                || country.rawValue.localizedCaseInsensitiveContains(searchText)
        }.map { country in
            PlaceSearchResult(
                id: "country-\(country.rawValue)",
                title: country.title,
                subtitle: onboardingString("location.countryResult"),
                flag: country.flag,
                countryCode: country.rawValue
            )
        }
    }

    var body: some View {
        OnboardingFloatingStep(
            buttonTitle: hasRequestedLocation ? onboardingString("location.confirm") : onboardingString("location.request"),
            action: {
                if hasRequestedLocation { continueAction() }
                else { Task { await locate() } }
            }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingTitle(title: onboardingString("location.title"), subtitle: "")
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        Image(systemName: "location.fill").foregroundStyle(Color.nomadSky).frame(width: 42, height: 42).background(Color.nomadSky.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(hasRequestedLocation ? (selectedCityName ?? onboardingString("location.detected")) : onboardingString("location.system"))
                                .font(.onboarding(17, weight: .semibold, relativeTo: .headline))
                            Text(hasRequestedLocation ? onboardingString("location.confirmHint") : onboardingString("location.usage"))
                                .font(.onboarding(12, relativeTo: .caption)).foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: hasRequestedLocation ? "checkmark.circle.fill" : "location.circle")
                            .foregroundStyle(Color.nomadSky)
                    }
                    .padding(16)
                    .background(Color.nomadSky.opacity(0.075), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await locate() } }

                    if let locationError {
                        VStack(alignment: .leading, spacing: 9) {
                            Text(locationError)
                                .font(.onboarding(12, relativeTo: .caption))
                                .foregroundStyle(.red)
                            if locationService.needsSettingsToGrantLocation {
                                Button {
                                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                                    UIApplication.shared.open(settingsURL)
                                } label: {
                                    Label("打开系统设置", systemImage: "gearshape")
                                        .font(.onboarding(13, weight: .semibold, relativeTo: .subheadline))
                                }
                                .buttonStyle(.bordered)
                                .tint(Color.nomadSky)
                            }
                        }
                    }

                    if isSearching {
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                                TextField(onboardingString("location.searchPlaceholder"), text: $searchText)
                                    .focused($searchFocused)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                Button(onboardingString("cancel")) {
                                    searchText = ""
                                    isSearching = false
                                    searchFocused = false
                                }
                                .font(.onboarding(14, weight: .semibold, relativeTo: .subheadline))
                                .foregroundStyle(.secondary)
                            }
                            .frame(height: 46)
                            .padding(.horizontal, 2)

                            ScrollView(showsIndicators: true) {
                                LazyVStack(spacing: 0) {
                                    ForEach(searchResults) { place in
                                        Button {
                                            select(place)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Text(place.flag).font(.system(size: 20))
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(place.title)
                                                    Text(place.subtitle)
                                                        .font(.onboarding(12, relativeTo: .caption))
                                                        .foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                            }
                                            .font(.onboarding(15, weight: .medium, relativeTo: .subheadline))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .frame(height: 52)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxHeight: 260)
                        }
                    } else {
                        Button {
                            isSearching = true
                            searchFocused = true
                        } label: {
                            HStack { Image(systemName: "magnifyingglass"); Text(onboardingString("location.change")); Spacer(); Image(systemName: "chevron.right") }
                                .font(.onboarding(15, weight: .medium, relativeTo: .subheadline)).foregroundStyle(.primary).padding(16).background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(PressableScaleButtonStyle())
                    }
                }
                .padding(.top, OnboardingLayout.sectionSpacing)
                Spacer()
            }
        }
    }

    private func locate() async {
        locationError = nil
        do {
            let place = try await locationService.currentPlace()
            userData.updateCurrentPlace(place)
            selectedCityName = place.city
            withAnimation(.smooth(duration: 0.22)) { hasRequestedLocation = true }
        } catch {
            locationError = error.localizedDescription
            isSearching = true
            searchFocused = true
        }
    }

    private func select(_ result: PlaceSearchResult) {
        userData.currentCountryCode = result.countryCode
        userData.currentCityName = result.title
        userData.currentDistrictName = ""
        userData.currentLatitude = nil
        userData.currentLongitude = nil
        selectedCityName = result.title
        hasRequestedLocation = true
        isSearching = false
        searchFocused = false
        searchText = ""
    }
}

private struct StayUntilStep: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isEnabled: Bool
    let continueAction: () -> Void

    var body: some View {
        OnboardingFloatingStep(buttonTitle: onboardingString("continue"), action: continueAction) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingTitle(title: onboardingString("stay.title"), subtitle: "")
                Toggle(onboardingString("stay.reminder"), isOn: $isEnabled)
                    .font(.subheadline.weight(.semibold))
                    .tint(Color.nomadSky)
                    .padding(.top, OnboardingLayout.sectionSpacing)
                if isEnabled {
                    VStack(spacing: 14) {
                        DatePicker(onboardingString("stay.arrival"), selection: $startDate, in: ...endDate, displayedComponents: .date)
                        DatePicker(onboardingString("stay.departure"), selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                    .datePickerStyle(.compact)
                    .font(.subheadline.weight(.medium))
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.top, 18)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge").foregroundStyle(Color.nomadSky)
                        Text(onboardingString("stay.later"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.top, OnboardingLayout.sectionSpacing)
                }
                Spacer()
            }
        }
        .animation(.smooth(duration: 0.22), value: isEnabled)
    }
}

private struct DepartureDateStep: View {
    @Binding var date: Date
    let continueAction: () -> Void

    var body: some View {
        OnboardingFloatingStep(buttonTitle: onboardingString("continue"), action: continueAction) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingTitle(title: onboardingString("departure.title"), subtitle: onboardingString("departure.subtitle"))
                DatePicker("", selection: $date, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .frame(height: 340, alignment: .top)
                    .padding(.top, OnboardingLayout.sectionSpacing)
                Spacer()
            }
        }
    }
}

private struct ToolsStep: View {
    @Binding var selection: Set<OnboardingView.KitTool>
    let continueAction: () -> Void

    private let tools: [OnboardingView.KitTool] = [
        .visa, .checklist,
        .coworking, .connectivity,
        .weather, .insurance,
        .exchange
    ]

    private let columns = [
        GridItem(.fixed(102), spacing: 54),
        GridItem(.fixed(102), spacing: 0)
    ]

    private var title: String {
        let value = onboardingString("tools.title")
        guard Locale.autoupdatingCurrent.language.languageCode?.identifier == "zh" else { return value }
        return value.replacingOccurrences(of: "对你最", with: "对你\n最")
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    Text(title)
                        .font(.onboarding(25, weight: .semibold, relativeTo: .title2))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 300)
                        .padding(.top, OnboardingLayout.titleTop)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(tools, id: \.self) { tool in
                            toolButton(tool)
                        }
                    }
                    .frame(width: 258)
                    .padding(.top, OnboardingLayout.sectionSpacing)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .frame(height: max(proxy.size.height - 86, 0), alignment: .top)
                .frame(maxHeight: .infinity, alignment: .top)

                Button(onboardingString("continue"), action: continueAction)
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                    .frame(maxWidth: 337)
            }
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.bottom, OnboardingLayout.buttonBottom)
    }

    private func toggle(_ tool: OnboardingView.KitTool) {
        if selection.contains(tool) { selection.remove(tool) } else { selection.insert(tool) }
    }

    private func toolButton(_ tool: OnboardingView.KitTool) -> some View {
        Button { toggle(tool) } label: {
            VStack(spacing: 9) {
                ToolArtwork(tool: tool)
                    .frame(width: 78, height: 78)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.nomadInk.opacity(0.08), radius: 12, y: 6)
                    .overlay(alignment: .topTrailing) {
                        selectionBadge(isSelected: selection.contains(tool))
                            .offset(x: 10, y: -7)
                    }

                Text(toolTitle(tool))
                    .font(.onboarding(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Color.nomadInk)
                    .frame(width: 102)
                    .lineLimit(1)
            }
            .frame(width: 102, height: 108, alignment: .top)
            .padding(.top, 5)
        }
        .buttonStyle(PressableScaleButtonStyle())
        .accessibilityLabel(tool.title)
        .accessibilityAddTraits(selection.contains(tool) ? .isSelected : [])
    }

    private func selectionBadge(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.nomadInk : Color.nomadLavender.opacity(0.48))
                .overlay { Circle().stroke(.white, lineWidth: 2) }
                .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 24, height: 24)
    }

    private func toolTitle(_ tool: OnboardingView.KitTool) -> String { tool.title }
}

private struct ToolArtwork: View {
    let tool: OnboardingView.KitTool

    var body: some View {
        switch tool {
        case .visa:
            VStack(spacing: -2) {
                Image("OnboardingVisa")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 43, height: 42)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("30").font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("Days").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                }
            }
        case .checklist:
            VStack(alignment: .leading, spacing: 6) {
                Text("To - do list")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                Text("• Finish report by 3pm\n• Book train tickets\n• Water the plants")
                    .font(.system(size: 7.4, weight: .medium, design: .rounded))
                    .lineSpacing(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.nomadSurface)
        case .coworking:
            artworkImage("OnboardingCoworking", contentMode: .fill)
        case .connectivity:
            artworkImage("OnboardingESIM", contentMode: .fill)
                .background(Color(red: 0.97, green: 0.97, blue: 0.95))
        case .insurance:
            artworkImage("OnboardingInsurance", contentMode: .fill)
        case .exchange:
            artworkImage("OnboardingExchange", contentMode: .fill)
        case .weather:
            ZStack(alignment: .topLeading) {
                Color.nomadBlue.opacity(0.14)
                VStack(alignment: .leading, spacing: 0) {
                    Text("May Saturday")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                    Text("25℃")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.nomadBlue)
                }
                .padding(9)
                Image(systemName: "cloud.bolt.rain.fill")
                    .font(.system(size: 34))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.nomadInk, Color.nomadYellow, Color.nomadBlue)
                    .offset(x: 43, y: 43)
            }
        }
    }

    private enum ArtworkContentMode { case fit, fill }

    private func artworkImage(_ name: String, contentMode: ArtworkContentMode) -> some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: contentMode == .fill ? .fill : .fit)
            .frame(width: 78, height: 78)
            .clipped()
    }
}

struct VisitedCountriesStep: View {
    @Binding var selection: Set<OnboardingView.Country>
    let continueAction: () -> Void

    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var filteredCountries: [OnboardingView.Country] {
        OnboardingView.Country.allCases
            .filter {
                searchText.isEmpty
                    || $0.englishName.localizedCaseInsensitiveContains(searchText)
                    || $0.title.localizedCaseInsensitiveContains(searchText)
                    || Locale(identifier: "zh_Hans").localizedString(forRegionCode: $0.rawValue)?.localizedCaseInsensitiveContains(searchText) == true
            }
            .sorted { $0.englishName < $1.englishName }
    }

    private var regularCountries: [OnboardingView.Country] {
        guard searchText.isEmpty else { return filteredCountries }
        let favoriteSet = Set(OnboardingView.Country.digitalNomadFavorites)
        return filteredCountries.filter { !favoriteSet.contains($0) }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Text(onboardingString("visited.title"))
                        .font(.onboarding(28, weight: .semibold, relativeTo: .title))
                        .foregroundStyle(Color.nomadInk)
                }
                .padding(.top, OnboardingLayout.titleTop)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color(red: 0.62, green: 0.63, blue: 0.65))

                    TextField(onboardingString("countries.search"), text: $searchText)
                        .focused($searchFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14, weight: .medium, design: .rounded))

                    Spacer(minLength: 8)

                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(selection.count)")
                            .foregroundStyle(Color.nomadInk)
                        Text("/200")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.nomadInk.opacity(0.5))
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    if searchFocused {
                        Button(onboardingString("cancel")) {
                            searchText = ""
                            searchFocused = false
                        }
                        .font(.onboarding(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 46)
                .padding(.horizontal, 21)
                .padding(.top, OnboardingLayout.sectionSpacing)
                .contentShape(Rectangle())
                .onTapGesture { searchFocused = true }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if searchText.isEmpty {
                            countrySectionTitle(onboardingString("visited.popular"))
                            ForEach(OnboardingView.Country.digitalNomadFavorites) { country in
                                countryRow(country)
                            }
                            countrySectionTitle(onboardingString("visited.all"))
                        }
                        ForEach(regularCountries) { country in
                            countryRow(country)
                        }
                        Color.clear.frame(height: 72)
                    }
                }
                .scrollIndicators(.visible)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .padding(.horizontal, 21)
                .padding(.top, 6)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .frame(height: max(proxy.size.height - 74, 0), alignment: .top)
                .frame(maxHeight: .infinity, alignment: .top)

                Button(onboardingString("continue"), action: continueAction)
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                    .frame(maxWidth: 337)
            }
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.bottom, OnboardingLayout.buttonBottom)
    }

    private func countryRow(_ country: OnboardingView.Country) -> some View {
        Button { toggle(country) } label: {
            HStack(spacing: 10) {
                Text(country.flag)
                    .font(.system(size: 19))
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())

                Text(country.title)
                    .font(.onboarding(14, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(Color.nomadInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer()

                if selection.contains(country) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.nomadInk)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableScaleButtonStyle())
        .accessibilityAddTraits(selection.contains(country) ? .isSelected : [])
    }

    private func countrySectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.onboarding(12, weight: .semibold, relativeTo: .caption))
            .foregroundStyle(Color.black.opacity(0.42))
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.bottom, 5)
    }

    private func toggle(_ country: OnboardingView.Country) {
        if selection.contains(country) {
            selection.remove(country)
        } else if selection.count < 200 {
            selection.insert(country)
        }
    }
}

private struct CountryPickerStep: View {
    let title: String
    let subtitle: String
    @Binding var selection: Set<OnboardingView.Country>
    let primaryTitle: String
    let allowSkip: Bool
    let continueAction: () -> Void
    @State private var searchText = ""

    private let popular: [OnboardingView.Country] = [
        .thailand, .indonesia, OnboardingView.Country(rawValue: "EE"),
        .malaysia, .portugal, OnboardingView.Country(rawValue: "BR"),
        .spain, .japan, OnboardingView.Country(rawValue: "CO")
    ]

    private var countries: [OnboardingView.Country] {
        OnboardingView.Country.allCases.filter {
            searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) || $0.englishName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        OnboardingFloatingStep(
            buttonTitle: primaryTitle,
            action: continueAction,
            isEnabled: !selection.isEmpty || allowSkip
        ) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingTitle(title: title, subtitle: subtitle)
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(onboardingString("countries.search"), text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .frame(height: 46)
                .padding(.top, OnboardingLayout.sectionSpacing)

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        if searchText.isEmpty {
                            Text(onboardingString("countries.popular"))
                                .font(.onboarding(12, weight: .semibold, relativeTo: .caption))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 10)
                            ForEach(popular, id: \.self) { country in
                                countryRow(country)
                            }
                        }
                        ForEach(groupedCountries, id: \.key) { group in
                            Section {
                                ForEach(group.value, id: \.self) { country in countryRow(country) }
                            } header: {
                                Text(group.key)
                                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var groupedCountries: [(key: String, value: [OnboardingView.Country])] {
        let popularSet = Set(popular)
        let remaining = searchText.isEmpty ? countries.filter { !popularSet.contains($0) } : countries
        return Dictionary(grouping: remaining, by: \.initial)
            .map { (key: $0.key, value: $0.value.sorted { $0.englishName < $1.englishName }) }
            .sorted { $0.key < $1.key }
    }

    private func countryRow(_ country: OnboardingView.Country) -> some View {
        Button { toggle(country) } label: {
            HStack(spacing: 12) {
                Text(country.flag).font(.title3)
                Text(country.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Spacer()
                Image(systemName: selection.contains(country) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selection.contains(country) ? Color.nomadSky : Color.black.opacity(0.2))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableScaleButtonStyle())
    }

    private func toggle(_ country: OnboardingView.Country) {
        if selection.contains(country) { selection.remove(country) } else { selection.insert(country) }
    }
}

private struct KitReadyStep: View {
    let stage: OnboardingView.JourneyStage
    let destination: OnboardingView.Country?
    let visitedCount: Int
    let action: () -> Void
    @State private var packed = false

    var body: some View {
        OnboardingFloatingStep(buttonTitle: onboardingString("ready.button"), action: action) {
            VStack(spacing: 0) {
                Spacer(minLength: 12)
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.nomadSurface)
                        .frame(width: 226, height: 155)
                        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.nomadInk.opacity(0.2), lineWidth: 2) }
                    Rectangle().fill(Color.nomadInk.opacity(0.24)).frame(width: 3, height: 154)
                    RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.nomadInk.opacity(0.34), lineWidth: 5).frame(width: 82, height: 27).offset(y: -91)
                    VStack(spacing: 6) {
                        Image(systemName: "suitcase.rolling.fill").font(.system(size: 38)).foregroundStyle(Color.nomadInk)
                        Text("NOMAD KIT").font(.vastago(11, weight: .bold, relativeTo: .caption2)).tracking(1.3).foregroundStyle(Color.nomadInk)
                    }
                    .rotationEffect(.degrees(-3))
                    .offset(x: 54, y: 12)
                    if visitedCount > 0 {
                        Text(destination?.flag ?? "🌏").font(.system(size: 28)).padding(8).background(.white, in: Circle()).rotationEffect(.degrees(14)).offset(x: -66, y: 25)
                    }
                }
                .scaleEffect(packed ? 1 : 0.9)
                .opacity(packed ? 1 : 0)
                .padding(.top, 44)
                Text(readyTitle)
                    .font(.onboarding(28, weight: .semibold, relativeTo: .title))
                    .multilineTextAlignment(.center)
                    .padding(.top, 46)
                Spacer()
            }
            .onAppear { withAnimation(.smooth(duration: 0.55).delay(0.12)) { packed = true } }
        }
    }

    private var readyTitle: String {
        switch stage {
        case .traveling: onboardingString("ready.traveling")
        case .preparing: onboardingString("ready.preparing")
        case .notTraveling: onboardingString("ready.notTraveling")
        }
    }

}

private struct OnboardingFloatingStep<Content: View>: View {
    let buttonTitle: String
    let action: () -> Void
    var isEnabled = true
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 74)

            Button(buttonTitle, action: action)
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .frame(maxWidth: 337)
                .disabled(!isEnabled)
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.bottom, OnboardingLayout.buttonBottom)
    }
}

private struct OnboardingTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text(title)
                .font(.onboarding(28, weight: .semibold, relativeTo: .title))
                .foregroundStyle(Color.nomadInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, OnboardingLayout.titleTop)
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.onboarding(17, weight: .semibold, relativeTo: .headline))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(Color.nomadInk, in: Capsule())
            .overlay { Capsule().stroke(.white.opacity(0.14), lineWidth: 0.75) }
            .shadow(color: Color.nomadInk.opacity(0.22), radius: 12, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
    }
}

private struct OnboardingBackdrop: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.77, green: 0.90, blue: 0.98), location: 0),
                    .init(color: Color(red: 0.91, green: 0.97, blue: 1.0), location: 0.22),
                    .init(color: .white, location: 0.43),
                    .init(color: .white, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 34) {
                onboardingLightBeam(rotation: -8, opacity: 0.46)
                onboardingLightBeam(rotation: 0, opacity: 0.68)
                onboardingLightBeam(rotation: 8, opacity: 0.46)
            }
            .frame(height: 330)
            .offset(y: -112)
            .blur(radius: 18)

            LinearGradient(
                colors: [.clear, .white.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 390)
        }
        .ignoresSafeArea()
    }

    private func onboardingLightBeam(rotation: Double, opacity: Double) -> some View {
        Capsule()
            .fill(Color.white.opacity(opacity))
            .frame(width: 86, height: 430)
            .rotationEffect(.degrees(rotation))
    }
}
