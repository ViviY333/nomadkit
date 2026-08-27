import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(UserDataStore.self) private var userData
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @State private var usesDarkMode = false
    @State private var downloadsOfflineMaps = false
    @State private var countryPicker: SettingsCountryPickerTarget?
    @State private var textEditor: SettingsTextEditorTarget?
    @State private var showsPaywall = false
    @State private var showsManageSubscriptions = false
    @State private var legalDocument: SubscriptionLegalDocument?
    @State private var showsLanguageSelection = false
    @State private var showsAppearanceSelection = false
    @State private var showsCurrentCountryPicker = false
    @State private var showsJourneyStagePicker = false
    @State private var isDownloadingOfflineMaps = false
    @State private var offlineMapError: String?
    @State private var signInErrorMessage: String?

    private var languageName: String {
        userData.preferredLanguageCode == "zh-Hans" ? "中文" : "English"
    }

    private func copy(_ zh: String, _ en: String) -> String {
        locale.identifier.hasPrefix("zh") ? zh : en
    }

    private var passportCountryName: String {
        locale.localizedString(forRegionCode: userData.passportNationality) ?? userData.passportNationality
    }

    private var currentCountryName: String {
        locale.localizedString(forRegionCode: userData.currentCountryCode) ?? userData.currentCountryCode
    }

    private var currentLocationName: String {
        let city = userData.currentCityName.trimmingCharacters(in: .whitespacesAndNewlines)
        return city.isEmpty ? currentCountryName : "\(city), \(currentCountryName)"
    }

    private var currentCountryFlag: String {
        userData.currentCountryCode.flagEmoji
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                SettingsCloudBackdrop(width: proxy.size.width)
                    .ignoresSafeArea(edges: .top)

                settingsContent
                    .frame(width: proxy.size.width)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(30)
        .sheet(item: $countryPicker) { target in
            SettingsCountryPicker(
                title: target.title(for: locale),
                initialCountryCode: target.currentCode(userData),
                onSave: { target.save($0, to: userData) }
            )
        }
        .sheet(isPresented: $showsCurrentCountryPicker) {
            SettingsCurrentCountryPicker { place in
                userData.updateCurrentPlace(place)
            }
        }
        .sheet(isPresented: $showsJourneyStagePicker) {
            SettingsJourneyStagePicker { stage in
                userData.journeyStageID = stage
                if stage == "traveling" {
                    let start = userData.currentStayStartedAt ?? .now
                    userData.currentStayStartedAt = start
                    userData.allowedStayUntil = userData.allowedStayUntil
                        ?? Calendar.current.date(byAdding: .day, value: 29, to: start)
                }
            }
        }
        .sheet(item: $textEditor) { target in
            SettingsTextEditor(
                title: target.title(for: locale),
                initialValue: target.currentValue(userData),
                onSave: { target.save($0, to: userData) }
            )
        }
        .sheet(isPresented: $showsPaywall) {
            SubscriptionPaywallView(entryPoint: .settings) { showsPaywall = false }
        }
        .sheet(item: $legalDocument) { document in
            SubscriptionLegalDocumentView(document: document)
        }
        .alert(locale.identifier.hasPrefix("zh") ? "登录失败" : "Sign in failed", isPresented: Binding(
            get: { signInErrorMessage != nil },
            set: { if !$0 { signInErrorMessage = nil } }
        )) {
            Button(locale.identifier.hasPrefix("zh") ? "好的" : "OK", role: .cancel) { signInErrorMessage = nil }
        } message: {
            Text(signInErrorMessage ?? (locale.identifier.hasPrefix("zh") ? "请稍后重试。" : "Please try again."))
        }
        .alert(locale.identifier.hasPrefix("zh") ? "离线数据下载失败" : "Offline download failed", isPresented: Binding(
            get: { offlineMapError != nil },
            set: { if !$0 { offlineMapError = nil } }
        )) {
            Button(locale.identifier.hasPrefix("zh") ? "好的" : "OK", role: .cancel) { offlineMapError = nil }
        } message: {
            Text(offlineMapError ?? "")
        }
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
    }

    private var settingsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 5)

                VStack(spacing: 12) {
                    SettingsCard {
                        Button {
                            if subscriptionStore.hasProAccess {
                                showsManageSubscriptions = true
                            } else {
                                showsPaywall = true
                            }
                        } label: {
                            SettingsValueRow(
                                icon: "crown.fill",
                                tone: .yellow,
                                title: subscriptionLocalized("subscription.settings.title", locale: locale),
                                value: subscriptionStore.hasProAccess
                                    ? subscriptionLocalized("subscription.settings.active", locale: locale)
                                    : subscriptionLocalized("subscription.settings.free", locale: locale)
                            )
                        }
                        Button {
                            Task { _ = await subscriptionStore.restorePurchases(entryPoint: .settings) }
                        } label: {
                            SettingsNavigationRow(icon: "arrow.clockwise", tone: .blue, title: subscriptionLocalized("subscription.settings.restore", locale: locale))
                        }
                    }
                    .buttonStyle(NomadPlainButtonStyle())

                    SettingsCard {
                        Button { textEditor = .displayName } label: {
                            SettingsValueRow(icon: "person.fill", tone: .blue, title: copy("显示名称", "Display name"), value: userData.profileDisplayName.isEmpty ? "vivi" : userData.profileDisplayName)
                        }
                        Button { countryPicker = .passport } label: {
                            SettingsValueRow(icon: "person.text.rectangle.fill", tone: .yellow, title: copy("护照", "Passport"), value: passportCountryName)
                        }
                        Button { showsCurrentCountryPicker = true } label: {
                            SettingsValueRow(
                                icon: "mappin.and.ellipse",
                                tone: .pink,
                                title: locale.identifier.hasPrefix("zh") ? "当前地点" : "Current place",
                                value: currentLocationName,
                                flag: currentCountryFlag
                            )
                        }
                        Button { showsJourneyStagePicker = true } label: {
                            SettingsValueRow(
                                icon: "airplane.circle.fill",
                                tone: .blue,
                                title: locale.identifier.hasPrefix("zh") ? "旅居状态" : "Travel status",
                                value: journeyStageName
                            )
                        }
                        SettingsToggleRow(
                            icon: "location.fill",
                            tone: .blue,
                            title: copy("使用当前位置", "Use current location"),
                            isOn: Binding(
                                get: { userData.usesCurrentLocation },
                                set: { userData.usesCurrentLocation = $0 }
                            )
                        )
                    }
                    .buttonStyle(NomadPlainButtonStyle())

                    SettingsCard {
                        Button { showsLanguageSelection = true } label: {
                            SettingsValueRow(icon: "character.bubble.fill", tone: .pink, title: languageTitle, value: languageName)
                        }
                        .popover(isPresented: $showsLanguageSelection, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                            LanguageSelectionView()
                                .fixedSize(horizontal: false, vertical: true)
                                .presentationCompactAdaptation(.popover)
                        }
                        Button { showsAppearanceSelection = true } label: {
                            SettingsValueRow(
                                icon: "circle.lefthalf.filled",
                                tone: .yellow,
                                title: appearanceTitle,
                                value: userData.appearancePreference.title(for: locale)
                            )
                        }
                        .popover(isPresented: $showsAppearanceSelection, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                            AppearanceSelectionView()
                                .fixedSize(horizontal: false, vertical: true)
                                .presentationCompactAdaptation(.popover)
                        }
                        Button { toggleOfflineMaps() } label: {
                            SettingsValueRow(
                                icon: "map.fill",
                                tone: .blue,
                                title: copy("离线地图", "Offline maps"),
                                value: offlineMapStatus
                            )
                        }
                        .disabled(isDownloadingOfflineMaps)
                        Text(appLocalized("cityDirectory.attribution", locale: locale))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    SettingsCard {
                        Button { legalDocument = .privacy } label: {
                            SettingsNavigationRow(icon: "hand.raised.fill", tone: .gray, title: subscriptionLocalized("subscription.privacy", locale: locale))
                        }
                        Button { legalDocument = .terms } label: {
                            SettingsNavigationRow(icon: "doc.text.fill", tone: .gray, title: subscriptionLocalized("subscription.terms", locale: locale))
                        }
                    }
                    .buttonStyle(NomadPlainButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
        }
    }

    private var header: some View {
        ZStack(alignment: .top) {
            HStack {
                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.09), radius: 8, y: 4)
                }
                .buttonStyle(NomadPlainButtonStyle())
                .accessibilityLabel(copy("关闭设置", "Close settings"))

                Spacer()
            }
            .padding(.top, 13)
            .padding(.horizontal, 13)

            VStack(spacing: 10) {
                Text(copy("设置", "Settings"))
                    .font(.vastago(20, weight: .semibold))
                    .foregroundStyle(.primary)

                ProfileAvatarView(size: 80, imageData: userData.profileAvatarData)
                    .overlay(Circle().stroke(.white.opacity(0.72), lineWidth: 2))

                if userData.isSignedInWithApple {
                    Label(signedInTitle, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(.ultraThinMaterial, in: Capsule())
                } else {
                    ZStack {
                        SignInWithAppleButton(.signIn, onRequest: configureAppleRequest, onCompletion: handleAppleResult)
                            .signInWithAppleButtonStyle(.black)
                            .accessibilityLabel(copy("通过 Apple 登录", "Sign in with Apple"))
                        HStack(spacing: 7) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 15, weight: .medium))
                            Text(copy("通过 Apple 登录", "Sign in with Apple"))
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                    .frame(width: 150, height: 34)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
                }
            }
            .padding(.top, 21)
        }
        .frame(height: 205)
    }

    private var languageTitle: String {
        copy("语言", "Language")
    }

    private var appearanceTitle: String {
        copy("外观", "Appearance")
    }

    private var signedInTitle: String {
        copy("已登录", "Signed in")
    }

    private var journeyStageName: String {
        switch userData.journeyStageID {
        case "traveling": copy("正在旅居", "Traveling")
        case "preparing": copy("正在计划", "Planning")
        case "notTraveling": copy("暂未旅居", "Not traveling")
        default: copy("未设置", "Not set")
        }
    }

    private var offlineMapStatus: String {
        if isDownloadingOfflineMaps { return copy("下载中…", "Downloading…") }
        if userData.hasOfflineMapPackage { return copy("已下载", "Downloaded") }
        return copy("未下载", "Not downloaded")
    }

    private func toggleOfflineMaps() {
        if userData.hasOfflineMapPackage {
            do {
                try OfflineMapStore.shared.remove()
                userData.hasOfflineMapPackage = false
                userData.offlineMapCityName = ""
            } catch {
                offlineMapError = error.localizedDescription
            }
            return
        }

        isDownloadingOfflineMaps = true
        Task {
            do {
                try await OfflineMapStore.shared.download()
                userData.hasOfflineMapPackage = OfflineMapStore.shared.isAvailable
                userData.offlineMapCityName = userData.currentCityName
            } catch {
                offlineMapError = error.localizedDescription
            }
            isDownloadingOfflineMaps = false
        }
    }

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            userData.appleUserIdentifier = credential.user
            if let email = credential.email, !email.isEmpty {
                userData.appleAccountEmail = email
            }
            if userData.profileDisplayName.isEmpty,
               let fullName = credential.fullName,
               !fullName.givenName.orEmpty.isEmpty || !fullName.familyName.orEmpty.isEmpty {
                let name = PersonNameComponentsFormatter.localizedString(from: fullName, style: .default, options: [])
                userData.profileDisplayName = name
            }
        case .failure(let error):
            guard (error as? ASAuthorizationError)?.code != .canceled else { return }
#if targetEnvironment(simulator)
            signInErrorMessage = locale.identifier.hasPrefix("zh")
                ? "模拟器无法完成 Apple 登录，请在真机上测试。"
                : "Sign in with Apple is unavailable in the Simulator. Test on a real device."
#else
            signInErrorMessage = locale.identifier.hasPrefix("zh") ? "登录失败，请稍后重试。" : "Sign in with Apple failed. Try again."
#endif
        }
    }
}

private extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}

private struct SettingsCloudBackdrop: View {
    let width: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            Image("SettingsCloud")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: 430)
                .clipped()
                .opacity(colorScheme == .dark ? 0.42 : 1)

            if colorScheme == .dark {
                Color.black.opacity(0.18)
                    .frame(width: width, height: 430)
            }

            LinearGradient(
                colors: [.clear, .white.opacity(0.08), Color(uiColor: .systemGroupedBackground)],
                startPoint: UnitPoint(x: 0.5, y: 0.48),
                endPoint: .bottom
            )
            .frame(width: width, height: 470)
        }
        .allowsHitTesting(false)
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 10) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity)
                .background(Color.nomadBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private enum SettingsIconTone {
    case blue, yellow, pink, gray

    var color: Color {
        switch self {
        case .blue: Color(red: 0.36, green: 0.65, blue: 0.97)
        case .yellow: Color(red: 0.95, green: 0.70, blue: 0.24)
        case .pink: Color(red: 0.91, green: 0.43, blue: 0.64)
        case .gray: Color(red: 0.48, green: 0.50, blue: 0.54)
        }
    }
}

private struct SettingsIcon: View {
    let symbol: String
    let tone: SettingsIconTone

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(tone.color)
            .frame(width: 40, height: 40)
            .background(tone.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct SettingsRowLayout<Trailing: View>: View {
    let icon: String
    let tone: SettingsIconTone
    let title: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: icon, tone: tone)
            Text(title)
                .font(.vastago(16, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 8)
            trailing
        }
        .frame(minHeight: 41)
    }
}

private struct SettingsValueRow: View {
    let icon: String
    let tone: SettingsIconTone
    let title: String
    let value: String
    var flag: String?

    var body: some View {
        SettingsRowLayout(icon: icon, tone: tone, title: title) {
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.trailing)
                if let flag {
                    Text(flag)
                        .font(.system(size: 20))
                }
            }
        }
    }
}

private struct SettingsToggleRow: View {
    let icon: String
    let tone: SettingsIconTone
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        SettingsRowLayout(icon: icon, tone: tone, title: title) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.nomadInk)
                .sensoryFeedback(.selection, trigger: isOn)
                .scaleEffect(x: 0.82, y: 0.82, anchor: .trailing)
                .frame(width: 54, alignment: .trailing)
                .accessibilityLabel(title)
        }
    }
}

private struct SettingsNavigationRow: View {
    let icon: String
    let tone: SettingsIconTone
    let title: String

    var body: some View {
        SettingsRowLayout(icon: icon, tone: tone, title: title) {
            EmptyView()
        }
    }
}

private enum SettingsCountryPickerTarget: String, Identifiable {
    case passport
    case currentCountry

    var id: String { rawValue }
    func title(for locale: Locale) -> String {
        locale.identifier.hasPrefix("zh")
            ? (self == .passport ? "护照" : "当前国家")
            : (self == .passport ? "Passport" : "Current country")
    }

    @MainActor func currentCode(_ userData: UserDataStore) -> String {
        self == .passport ? userData.passportNationality : userData.currentCountryCode
    }

    @MainActor func save(_ countryCode: String, to userData: UserDataStore) {
        switch self {
        case .passport: userData.passportNationality = countryCode
        case .currentCountry: userData.currentCountryCode = countryCode
        }
    }
}

private enum SettingsTextEditorTarget: String, Identifiable {
    case displayName

    var id: String { rawValue }
    func title(for locale: Locale) -> String {
        locale.identifier.hasPrefix("zh") ? "显示名称" : "Display name"
    }

    @MainActor func currentValue(_ userData: UserDataStore) -> String {
        userData.profileDisplayName
    }

    @MainActor func save(_ value: String, to userData: UserDataStore) {
        userData.profileDisplayName = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SettingsCountry: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }
    var flag: String { code.flagEmoji }
}

private struct SettingsCountryPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var searchText = ""
    @State private var selectedCountryCode: String
    let title: String
    let onSave: (String) -> Void

    init(title: String, initialCountryCode: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.onSave = onSave
        _selectedCountryCode = State(initialValue: initialCountryCode)
    }

    private var countries: [SettingsCountry] {
        Locale.Region.isoRegions
            .compactMap { region in
                let code = region.identifier
                guard code.isISO3166CountryCode,
                      let name = locale.localizedString(forRegionCode: code) else { return nil }
                return SettingsCountry(code: code, name: name)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var filteredCountries: [SettingsCountry] {
        guard !searchText.isEmpty else { return countries }
        return countries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredCountries) { country in
                Button {
                    selectedCountryCode = country.code
                } label: {
                    HStack(spacing: 12) {
                        Text(country.flag).font(.title3)
                        Text(country.name).foregroundStyle(.primary)
                        Spacer()
                        if selectedCountryCode == country.code {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.nomadSky)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(NomadPlainButtonStyle())
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Text(locale.identifier.hasPrefix("zh") ? "搜索国家" : "Search countries"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(locale.identifier.hasPrefix("zh") ? "完成" : "Done") {
                        onSave(selectedCountryCode)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct SettingsCurrentCountryPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var searchText = ""
    @State private var selectedCountryCode = ""
    @State private var isLocating = false
    @State private var errorMessage: String?
    @State private var showsCityPicker = false
    @State private var locationService = LocationService()
    let onSave: (ResolvedPlace) -> Void

    private var countries: [SettingsCountry] {
        Locale.Region.isoRegions
            .compactMap { region in
                let code = region.identifier
                guard code.isISO3166CountryCode,
                      let name = locale.localizedString(forRegionCode: code) else { return nil }
                return SettingsCountry(code: code, name: name)
            }
            .filter {
                searchText.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.code.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await locate() }
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(symbol: "location.fill", tone: .blue)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(locale.identifier.hasPrefix("zh") ? "自动授权读取当前位置" : "Use Current Location")
                                    .font(.headline)
                                Text(locale.identifier.hasPrefix("zh") ? "自动获取当前城市和国家" : "Detect your current city and country")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isLocating { ProgressView().controlSize(.small) }
                        }
                    }
                    .buttonStyle(NomadPlainButtonStyle())
                    .disabled(isLocating)
                }

                Section(locale.identifier.hasPrefix("zh") ? "选择国家后选择城市" : "Choose a country, then a city") {
                    ForEach(countries) { country in
                        Button {
                            selectedCountryCode = country.code
                            showsCityPicker = true
                        } label: {
                            HStack(spacing: 12) {
                                Text(country.flag).font(.title3)
                                Text(country.name).foregroundStyle(.primary)
                                Spacer()
                                if selectedCountryCode == country.code {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.nomadBlue)
                                }
                            }
                        }
                        .buttonStyle(NomadPlainButtonStyle())
                    }
                }
            }
            .navigationTitle(locale.identifier.hasPrefix("zh") ? "当前地点" : "Current place")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: locale.identifier.hasPrefix("zh") ? "搜索国家" : "Search countries")
            .alert(locale.identifier.hasPrefix("zh") ? "无法获取当前位置" : "Unable to get location", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(locale.identifier.hasPrefix("zh") ? "好的" : "OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showsCityPicker) {
                SettingsCityPicker(countryCode: selectedCountryCode) { place in
                    onSave(place)
                    dismiss()
                }
            }
        }
    }

    private func locate() async {
        isLocating = true
        defer { isLocating = false }
        do {
            onSave(try await locationService.currentPlace())
            dismiss()
        } catch {
            errorMessage = localizedLocationError(error, locale: locale)
        }
    }
}

private struct SettingsJourneyStagePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let onSave: (String) -> Void

    private var options: [(id: String, title: String, detail: String, symbol: String)] {
        if locale.identifier.hasPrefix("zh") {
            return [
                ("traveling", "正在旅居", "当前正在这座城市生活", "location.fill"),
                ("preparing", "正在计划", "准备下一段旅居", "airplane.departure"),
                ("notTraveling", "暂未旅居", "先保存想去的城市", "globe.asia.australia")
            ]
        }
        return [
            ("traveling", "Traveling", "Living in this city now", "location.fill"),
            ("preparing", "Planning", "Preparing your next stay", "airplane.departure"),
            ("notTraveling", "Not traveling", "Keep a city on your list", "globe.asia.australia")
        ]
    }

    var body: some View {
        NavigationStack {
            List(options, id: \.id) { option in
                Button {
                    onSave(option.id)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: option.symbol)
                            .frame(width: 30, height: 30)
                            .foregroundStyle(Color.nomadInk)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.title).font(.headline)
                            Text(option.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(NomadPlainButtonStyle())
            }
            .navigationTitle(locale.identifier.hasPrefix("zh") ? "旅居状态" : "Travel status")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

private struct SettingsCityPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let countryCode: String
    let onSave: (ResolvedPlace) -> Void
    @State private var cityName = ""
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var locationService = LocationService()

    private var countryName: String {
        locale.localizedString(forRegionCode: countryCode) ?? countryCode
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(locale.identifier.hasPrefix("zh") ? "当前国家" : "Current country") {
                    HStack {
                        Text(countryCode.flagEmoji).font(.title2)
                        Text(countryName)
                    }
                }
                Section(locale.identifier.hasPrefix("zh") ? "城市" : "City") {
                    TextField(locale.identifier.hasPrefix("zh") ? "输入城市名称" : "Enter a city", text: $cityName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    Button {
                        Task { await searchCity() }
                    } label: {
                        HStack {
                            Text(locale.identifier.hasPrefix("zh") ? "确认城市" : "Confirm City")
                            Spacer()
                            if isSearching { ProgressView().controlSize(.small) }
                        }
                    }
                    .disabled(cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                }
            }
            .navigationTitle(locale.identifier.hasPrefix("zh") ? "选择城市" : "Choose City")
            .navigationBarTitleDisplayMode(.inline)
            .alert(locale.identifier.hasPrefix("zh") ? "找不到城市" : "City not found", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(locale.identifier.hasPrefix("zh") ? "好的" : "OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func searchCity() async {
        isSearching = true
        defer { isSearching = false }
        do {
            let place = try await locationService.resolve(city: cityName, countryName: countryName)
            onSave(place)
            dismiss()
        } catch {
            errorMessage = localizedLocationError(error, locale: locale)
        }
    }
}

private struct SettingsTextEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var value: String
    let title: String
    let onSave: (String) -> Void

    init(title: String, initialValue: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.onSave = onSave
        _value = State(initialValue: initialValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(title, text: $value)
                    .textContentType(.nickname)
                    .autocorrectionDisabled()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(locale.identifier.hasPrefix("zh") ? "完成" : "Done") {
                        onSave(value)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private extension String {
    var isISO3166CountryCode: Bool {
        count == 2 && unicodeScalars.allSatisfy { scalar in
            (65...90).contains(Int(scalar.value))
        }
    }

    var flagEmoji: String {
        let normalizedCode = uppercased()
        guard normalizedCode.isISO3166CountryCode else { return "🌐" }
        return normalizedCode.unicodeScalars.compactMap { scalar in
            guard let regionalIndicator = UnicodeScalar(127397 + scalar.value) else { return nil }
            return String(regionalIndicator)
        }.joined()
    }
}

private struct LanguageOption: Identifiable {
    let id: String
    let name: String
}

struct LanguageSelectionView: View {
    @Environment(UserDataStore.self) private var userData
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    private let languages = [
        LanguageOption(id: "en", name: "English"),
        LanguageOption(id: "zh-Hans", name: "中文")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(locale.identifier.hasPrefix("zh") ? "语言" : "Language")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.top, 12)
            ForEach(languages) { language in
                Button {
                    userData.preferredLanguageCode = language.id
                    dismiss()
                } label: {
                    selectionRow(title: language.name, isSelected: selectedLanguageID == language.id)
                }
                .foregroundStyle(.primary)
            }
        }
        .frame(minWidth: 240, idealWidth: 240, maxWidth: 240)
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var selectedLanguageID: String {
        userData.preferredLanguageCode.isEmpty ? "en" : userData.preferredLanguageCode
    }

    private func selectionRow(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct AppearanceSelectionView: View {
    @Environment(UserDataStore.self) private var userData
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(locale.identifier.hasPrefix("zh") ? "外观" : "Appearance")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.top, 12)
            ForEach(AppearancePreference.allCases) { preference in
                Button {
                    userData.appearancePreference = preference
                    dismiss()
                } label: {
                    HStack {
                        Text(preference.title(for: locale))
                        Spacer()
                        if userData.appearancePreference == preference {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .contentShape(Rectangle())
                }
                .foregroundStyle(.primary)
                .buttonStyle(NomadPlainButtonStyle())
            }
        }
        .frame(minWidth: 240, idealWidth: 240, maxWidth: 240)
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
