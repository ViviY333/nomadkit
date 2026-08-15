import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(UserDataStore.self) private var userData
    @State private var usesCurrentLocation = false
    @State private var usesDarkMode = false
    @State private var downloadsOfflineMaps = false
    @State private var countryPicker: SettingsCountryPickerTarget?
    @State private var textEditor: SettingsTextEditorTarget?

    private var languageName: String {
        guard !userData.preferredLanguageCode.isEmpty else { return "English" }
        return locale.localizedString(forLanguageCode: userData.preferredLanguageCode)
            ?? userData.preferredLanguageCode
    }

    private var passportCountryName: String {
        locale.localizedString(forRegionCode: userData.passportNationality) ?? userData.passportNationality
    }

    private var currentCountryName: String {
        locale.localizedString(forRegionCode: userData.currentCountryCode) ?? userData.currentCountryCode
    }

    private var currentCountryFlag: String {
        userData.currentCountryCode.flagEmoji
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color(red: 0.949, green: 0.949, blue: 0.969)
                    .ignoresSafeArea()

                SettingsCloudBackdrop(width: proxy.size.width)
                    .ignoresSafeArea(edges: .top)

                settingsContent
                    .frame(width: proxy.size.width)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Color(red: 0.949, green: 0.949, blue: 0.969).ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(30)
        .sheet(item: $countryPicker) { target in
            SettingsCountryPicker(
                title: target.title,
                initialCountryCode: target.currentCode(userData),
                onSave: { target.save($0, to: userData) }
            )
        }
        .sheet(item: $textEditor) { target in
            SettingsTextEditor(
                title: target.title,
                initialValue: target.currentValue(userData),
                onSave: { target.save($0, to: userData) }
            )
        }
    }

    private var settingsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 5)

                VStack(spacing: 12) {
                    SettingsCard {
                        Button { textEditor = .displayName } label: {
                            SettingsValueRow(icon: "person.fill", tone: .blue, title: "Display Name", value: userData.profileDisplayName.isEmpty ? "vivi" : userData.profileDisplayName)
                        }
                        Button { countryPicker = .passport } label: {
                            SettingsValueRow(icon: "person.text.rectangle.fill", tone: .orange, title: "Passport", value: passportCountryName)
                        }
                        Button { countryPicker = .currentCountry } label: {
                            SettingsValueRow(icon: "mappin.and.ellipse", tone: .rose, title: "Current country", value: currentCountryName, flag: currentCountryFlag)
                        }
                        SettingsToggleRow(icon: "location.fill", tone: .mint, title: "Use current Location", isOn: $usesCurrentLocation)
                    }
                    .buttonStyle(.plain)

                    SettingsCard {
                        SettingsValueRow(icon: "character.bubble.fill", tone: .lavender, title: "Language", value: languageName)
                        SettingsToggleRow(icon: "moon.fill", tone: .yellow, title: "Dark Mode", isOn: $usesDarkMode)
                        SettingsToggleRow(icon: "map.fill", tone: .teal, title: "Offline Maps", isOn: $downloadsOfflineMaps)
                    }

                    SettingsCard {
                        SettingsNavigationRow(icon: "hand.raised.fill", tone: .pink, title: "Privacy policy")
                        SettingsNavigationRow(icon: "doc.text.fill", tone: .indigo, title: "Terms and conditions")
                    }
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
                        .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.09), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close settings")

                Spacer()
            }
            .padding(.top, 13)
            .padding(.horizontal, 13)

            VStack(spacing: 10) {
                Text("Settings")
                    .font(.vastago(20, weight: .semibold))
                    .foregroundStyle(.black)

                ProfileAvatarView(size: 80, imageData: userData.profileAvatarData)
                    .overlay(Circle().stroke(.white.opacity(0.72), lineWidth: 2))

                Label("Sign in", systemImage: "apple.logo")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .padding(.leading, 14)
                    .padding(.trailing, 10)
                    .frame(height: 34)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
            }
            .padding(.top, 21)
        }
        .frame(height: 205)
    }
}

private struct SettingsCloudBackdrop: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            Image("SettingsCloud")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: 430)
                .clipped()

            LinearGradient(
                colors: [.clear, .white.opacity(0.12), Color(red: 0.949, green: 0.949, blue: 0.969)],
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
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private enum SettingsIconTone {
    case blue, orange, rose, mint, lavender, yellow, teal, pink, indigo

    var color: Color {
        switch self {
        case .blue: Color(red: 0.36, green: 0.65, blue: 0.97)
        case .orange: Color(red: 0.95, green: 0.61, blue: 0.30)
        case .rose: Color(red: 0.93, green: 0.43, blue: 0.51)
        case .mint: Color(red: 0.31, green: 0.76, blue: 0.62)
        case .lavender: Color(red: 0.56, green: 0.50, blue: 0.90)
        case .yellow: Color(red: 0.95, green: 0.70, blue: 0.24)
        case .teal: Color(red: 0.26, green: 0.68, blue: 0.75)
        case .pink: Color(red: 0.91, green: 0.43, blue: 0.64)
        case .indigo: Color(red: 0.34, green: 0.47, blue: 0.83)
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
                .foregroundStyle(Color(red: 0.095, green: 0.095, blue: 0.106))
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
                    .foregroundStyle(Color(red: 0.44, green: 0.44, blue: 0.48))
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
    var title: String { self == .passport ? "Passport" : "Current country" }

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
    var title: String { "Display Name" }

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
                .buttonStyle(.plain)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search countries")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(selectedCountryCode)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct SettingsTextEditor: View {
    @Environment(\.dismiss) private var dismiss
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
                    Button("Done") {
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
    @State private var searchText = ""

    private var languages: [LanguageOption] {
        Locale.LanguageCode.isoLanguageCodes
            .compactMap { code in
                let id = code.identifier
                guard let name = Locale.current.localizedString(forLanguageCode: id) else { return nil }
                return LanguageOption(id: id, name: name.capitalized(with: .current))
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var filteredLanguages: [LanguageOption] {
        guard !searchText.isEmpty else { return languages }
        return languages.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Button {
                userData.preferredLanguageCode = ""
            } label: {
                selectionRow(title: "English", isSelected: userData.preferredLanguageCode.isEmpty)
            }
            .foregroundStyle(.primary)

            Section("All languages") {
                ForEach(filteredLanguages) { language in
                    Button {
                        userData.preferredLanguageCode = language.id
                    } label: {
                        selectionRow(title: language.name, isSelected: userData.preferredLanguageCode == language.id)
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search languages")
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
