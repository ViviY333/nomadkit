import CoreLocation
import MapKit
import Photos
import SwiftUI

private struct PhotoPlaceSuggestion: Identifiable, Hashable {
    let id = UUID()
    let countryCode: String
    let city: String
    let latitude: Double
    let longitude: Double
    let photoCount: Int

    var countryName: LocalizedCopy { CountryCatalog.name(for: countryCode) }
}

private struct PhotoPlaceImporter {
    func suggestions(from assets: PHFetchResult<PHAsset>, progress: @escaping (Int, Int) -> Void) async -> [PhotoPlaceSuggestion] {
        guard assets.count > 0 else { return [] }
        var grouped: [String: (city: String, code: String, coordinate: CLLocationCoordinate2D, count: Int)] = [:]
        var geocoderCache: [String: CLPlacemark] = [:]

        for index in 0..<assets.count {
            let asset = assets.object(at: index)
            guard let location = asset.location else { continue }
            let cacheKey = "\(location.coordinate.latitude.rounded(toPlaces: 3)):\(location.coordinate.longitude.rounded(toPlaces: 3))"
            let mark: CLPlacemark?
            if let cached = geocoderCache[cacheKey] {
                mark = cached
            } else {
                mark = await reverseGeocode(location)
                if let mark { geocoderCache[cacheKey] = mark }
            }
            guard let mark,
                  let code = mark.isoCountryCode else { continue }
            let city = mark.locality ?? mark.subAdministrativeArea ?? mark.administrativeArea ?? ""
            guard !city.isEmpty else { continue }
            let key = "\(code)-\(city)".lowercased()
            if let current = grouped[key] {
                grouped[key] = (current.city, current.code, current.coordinate, current.count + 1)
            } else {
                grouped[key] = (city, code, location.coordinate, 1)
            }
            if index == 0 || index.isMultiple(of: 5) || index == assets.count - 1 {
                progress(index + 1, assets.count)
            }
        }

        return grouped.values.map {
            PhotoPlaceSuggestion(countryCode: $0.code, city: $0.city, latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude, photoCount: $0.count)
        }
        .sorted { $0.city < $1.city }
    }

    private func reverseGeocode(_ location: CLLocation) async -> CLPlacemark? {
        for attempt in 0..<2 {
            if let result = try? await CLGeocoder().reverseGeocodeLocation(location).first { return result }
            if attempt == 0 { try? await Task.sleep(for: .milliseconds(250)) }
        }
        return nil
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10, Double(places))
        return (self * factor).rounded() / factor
    }
}

struct AddPlacesView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case photos, manual
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(UserDataStore.self) private var userData
    @Environment(\.locale) private var locale
    let onPlacesAdded: ([TravelVisit]) -> Void
    @State private var mode: Mode
    @State private var suggestions: [PhotoPlaceSuggestion] = []
    @State private var selectedSuggestions: Set<PhotoPlaceSuggestion.ID> = []
    @State private var isScanning = false
    @State private var scannedPhotoCount = 0
    @State private var totalPhotoCount = 0
    @State private var countrySearchText = ""
    @State private var selectedCountryCode = ""
    @State private var citySearchText = ""
    @State private var cityResults: [ResolvedPlace] = []
    @State private var isSearchingCities = false
    @State private var photoAccessIsLimited = false
    @State private var photoScanMessage: String?

    private var appLocale: Locale {
        Locale(identifier: userData.preferredLanguageCode == "zh-Hans" ? "zh-Hans" : "en")
    }

    init(initialMode: Mode = .photos, onPlacesAdded: @escaping ([TravelVisit]) -> Void = { _ in }) {
        _mode = State(initialValue: initialMode)
        self.onPlacesAdded = onPlacesAdded
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Picker(appLocalized("addplaces.mode.label", locale: appLocale), selection: $mode) {
                        ForEach(Mode.allCases) { option in
                            Text(appLocalized(option == .photos ? "addplaces.mode.photos" : "addplaces.mode.manual", locale: appLocale))
                                .tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .sensoryFeedback(.selection, trigger: mode)

                    if mode == .photos {
                        photoSection
                    } else {
                        manualSection
                    }

                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
            .background(Color.nomadBackground)
            .navigationTitle(appLocalized("addplaces.title", locale: appLocale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appLocalized("common.cancel", locale: appLocale)) { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                }
                if mode == .manual {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(appLocalized("addplaces.done", locale: appLocale)) { dismiss() }
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.nomadBlue, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
            .environment(\.locale, appLocale)
            .task(id: mode) {
            guard mode == .photos, suggestions.isEmpty else { return }
            await scanPhotos()
        }
            .task(id: selectedCountryCode) {
                guard !selectedCountryCode.isEmpty else { return }
                await loadCities()
            }
            .alert(appLocalized("addplaces.photos.noResults", locale: appLocale), isPresented: Binding(get: { photoScanMessage != nil }, set: { if !$0 { photoScanMessage = nil } })) {
                Button(appLocalized("common.done", locale: appLocale), role: .cancel) { photoScanMessage = nil }
            }
    }

    @ViewBuilder private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(appLocalized("addplaces.photos.autoScan", locale: appLocale), systemImage: "photo.on.rectangle.angled")
                .font(.vastago(17, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(appLocalized("addplaces.photos.autoScanDetail", locale: appLocale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if photoAccessIsLimited {
                Button(appLocalized("addplaces.photos.openSettings", locale: appLocale)) {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        if isScanning {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(appLocalized("addplaces.photos.scanning", locale: appLocale))
                    .font(.footnote.weight(.medium))
                Spacer()
                Text(String.localizedStringWithFormat(appLocalized("addplaces.photos.progress", locale: appLocale), scannedPhotoCount, totalPhotoCount))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(scannedPhotoCount), total: Double(max(totalPhotoCount, 1)))
                .tint(Color.nomadBlue)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(appLocalized("addplaces.photos.detected", locale: appLocale))
                    .font(.vastago(18, weight: .semibold))
                ForEach(suggestions) { suggestion in
                    Button {
                        toggle(suggestion)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedSuggestions.contains(suggestion.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedSuggestions.contains(suggestion.id) ? Color.nomadBlue : .secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.city).foregroundStyle(Color.nomadInk)
                                Text(String.localizedStringWithFormat(appLocalized("addplaces.photos.count", locale: appLocale), suggestion.countryName.value(for: appLocale), suggestion.photoCount))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(NomadPlainButtonStyle())
                }
                Button(appLocalized("addplaces.photos.addSelected", locale: appLocale)) { addSelectedSuggestions() }
                    .disabled(selectedSuggestions.isEmpty)
            }
        }
    }

    @ViewBuilder private var manualSection: some View {
        if selectedCountryCode.isEmpty {
            countryList
        } else {
            cityList
        }
    }

    private var countryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appLocalized("addplaces.manual.countries", locale: appLocale))
                .font(.vastago(18, weight: .semibold))

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(appLocalized("addplaces.countryPicker.search", locale: appLocale), text: $countrySearchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !countrySearchText.isEmpty {
                    Button { countrySearchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(NomadPlainButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            LazyVStack(spacing: 0) {
                ForEach(filteredCountries) { country in
                    countryRow(country)
                    if country.id != filteredCountries.last?.id {
                        Divider().padding(.leading, 34)
                    }
                }
            }
        }
    }

    private var cityList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                selectedCountryCode = ""
                citySearchText = ""
                cityResults = []
            } label: {
                Label(appLocalized("addplaces.countryPicker.backToCountries", locale: appLocale), systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(NomadPlainButtonStyle())

            Text(CountryCatalog.name(for: selectedCountryCode).value(for: appLocale))
                .font(.vastago(22, weight: .semibold))
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(appLocalized("addplaces.countryPicker.cityPlaceholder", locale: appLocale), text: $citySearchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await loadCities(search: citySearchText) } }
                Button {
                    Task { await loadCities(search: citySearchText) }
                } label: {
                    Text(appLocalized("addplaces.countryPicker.searchCity", locale: appLocale))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.nomadBlue)
                }
                .disabled(isSearchingCities)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if isSearchingCities { ProgressView().frame(maxWidth: .infinity) }
            if !isSearchingCities && visibleCityResults.isEmpty {
                Text(appLocalized(citySearchText.isEmpty ? "addplaces.countryPicker.noCities" : "addplaces.countryPicker.noSearchResults", locale: appLocale))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            }
            ForEach(Array(visibleCityResults.enumerated()), id: \.offset) { _, place in
                Button { addCity(place) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(place.city).font(.body.weight(.semibold))
                            if !place.district.isEmpty { Text(place.district).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Image(systemName: "plus.circle").foregroundStyle(Color.nomadBlue)
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(NomadPlainButtonStyle())
            }
        }
    }

    private var visibleCityResults: [ResolvedPlace] {
        let query = citySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return cityResults }
        return cityResults.filter { $0.city.localizedCaseInsensitiveContains(query) || $0.district.localizedCaseInsensitiveContains(query) }
    }

    private var filteredCountries: [OnboardingView.Country] {
        OnboardingView.Country.allCases.filter { country in
            countrySearchText.isEmpty
                || country.englishName.localizedCaseInsensitiveContains(countrySearchText)
                || (appLocale.localizedString(forRegionCode: country.rawValue) ?? country.englishName).localizedCaseInsensitiveContains(countrySearchText)
                || country.rawValue.localizedCaseInsensitiveContains(countrySearchText)
                || Locale(identifier: "zh_Hans").localizedString(forRegionCode: country.rawValue)?.localizedCaseInsensitiveContains(countrySearchText) == true
        }
    }

    private func countryRow(_ country: OnboardingView.Country) -> some View {
        let isExisting = userData.recordedCountryCodes.contains(country.rawValue)
        let isSelected = isExisting
        return Button {
            selectedCountryCode = country.rawValue
            citySearchText = ""
            cityResults = []
        } label: {
            HStack(spacing: 10) {
                Text(country.flag).font(.system(size: 19)).frame(width: 24)
                Text(appLocale.localizedString(forRegionCode: country.rawValue) ?? country.englishName)
                    .font(.vastago(15, weight: .medium))
                    .foregroundStyle(Color.nomadInk)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right.circle")
                    .foregroundStyle(isSelected ? Color.nomadInk.opacity(0.35) : Color.nomadBlue)
            }
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(NomadPlainButtonStyle())
        .accessibilityLabel(appLocale.localizedString(forRegionCode: country.rawValue) ?? country.englishName)
    }

    private func scanPhotos() async {
        isScanning = true
        scannedPhotoCount = 0
        totalPhotoCount = 0
        let authorization = await requestPhotoAccess()
        guard authorization == .authorized || authorization == .limited else {
            isScanning = false
            return
        }
        photoAccessIsLimited = authorization == .limited
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: options)
        totalPhotoCount = assets.count
        suggestions = await PhotoPlaceImporter().suggestions(from: assets) { scanned, total in
            scannedPhotoCount = scanned
            totalPhotoCount = total
        }
        selectedSuggestions = Set(suggestions.map(\.id))
        isScanning = false
        if suggestions.isEmpty { photoScanMessage = appLocalized("addplaces.photos.noResults", locale: appLocale) }
    }

    private func requestPhotoAccess() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func loadCities(search: String = "") async {
        guard !selectedCountryCode.isEmpty else { return }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = CityDirectory()
        let localResults = query.isEmpty
            ? directory.cities(for: selectedCountryCode, limit: 80)
            : directory.search(query, countryCode: selectedCountryCode)
        if !localResults.isEmpty {
            cityResults = localResults.map {
                ResolvedPlace(city: $0.name, district: $0.admin1, countryCode: $0.countryCode, latitude: $0.latitude, longitude: $0.longitude)
            }
            return
        }
        isSearchingCities = true
        defer { isSearchingCities = false }
        let request = MKLocalSearch.Request()
        let countryName = CountryCatalog.name(for: selectedCountryCode).en
        request.naturalLanguageQuery = query.isEmpty ? "cities in \(countryName)" : "\(query), \(countryName)"
        request.resultTypes = [.address, .pointOfInterest]
        guard let response = try? await MKLocalSearch(request: request).start() else { return }
        var seen = Set<String>()
        cityResults = response.mapItems.compactMap { item in
            guard let code = item.placemark.countryCode, CountryCatalog.code(for: code) == selectedCountryCode else { return nil }
            let city = item.placemark.locality ?? item.placemark.subAdministrativeArea ?? item.name ?? query
            guard !city.isEmpty, seen.insert(city.lowercased()).inserted else { return nil }
            let coordinate = item.placemark.coordinate
            return ResolvedPlace(city: city, district: item.placemark.subLocality ?? "", countryCode: code, latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
        // A country-wide query can return no city records on some MapKit locales.
        // Retry with the country name so the user still gets a usable list.
        if cityResults.isEmpty && query.isEmpty {
            let fallback = MKLocalSearch.Request()
            fallback.naturalLanguageQuery = countryName
            fallback.resultTypes = [.address, .pointOfInterest]
            if let fallbackResponse = try? await MKLocalSearch(request: fallback).start() {
                cityResults = fallbackResponse.mapItems.compactMap { item in
                    guard let code = item.placemark.countryCode, CountryCatalog.code(for: code) == selectedCountryCode else { return nil }
                    let city = item.placemark.locality ?? item.placemark.subAdministrativeArea ?? item.name ?? ""
                    guard !city.isEmpty, seen.insert(city.lowercased()).inserted else { return nil }
                    let coordinate = item.placemark.coordinate
                    return ResolvedPlace(city: city, district: item.placemark.subLocality ?? "", countryCode: code, latitude: coordinate.latitude, longitude: coordinate.longitude)
                }
            }
        }
    }

    private func addCity(_ place: ResolvedPlace) {
        let before = Set(userData.visits.map(\.id))
        let code = CountryCatalog.code(for: place.countryCode)
        _ = userData.addPlace(cityID: "manual-\(code)-\(place.city.lowercased().replacingOccurrences(of: " ", with: "-"))", cityName: LocalizedCopy(zhHans: place.city, en: place.city), countryCode: code, countryName: CountryCatalog.name(for: code), latitude: place.latitude, longitude: place.longitude, source: .manual)
        let added = userData.visits.filter { !before.contains($0.id) }
        if !added.isEmpty { onPlacesAdded(added) }
        selectedCountryCode = ""
        citySearchText = ""
        cityResults = []
    }

    private func addSelectedSuggestions() {
        let before = Set(userData.visits.map(\.id))
        for suggestion in suggestions where selectedSuggestions.contains(suggestion.id) {
            let name = LocalizedCopy(zhHans: suggestion.city, en: suggestion.city)
            _ = userData.addPlace(cityID: "photo-\(suggestion.countryCode)-\(suggestion.city.lowercased().replacingOccurrences(of: " ", with: "-"))", cityName: name, countryCode: suggestion.countryCode, countryName: suggestion.countryName, latitude: suggestion.latitude, longitude: suggestion.longitude, source: .photo)
        }
        finishAdding(since: before)
    }

    private func finishAdding(since before: Set<UUID>) {
        let added = userData.visits.filter { !before.contains($0.id) }
        guard !added.isEmpty else { return }
        onPlacesAdded(added)
        dismiss()
    }

    private func toggle(_ suggestion: PhotoPlaceSuggestion) {
        if selectedSuggestions.contains(suggestion.id) { selectedSuggestions.remove(suggestion.id) }
        else { selectedSuggestions.insert(suggestion.id) }
    }
}

private struct AddPlacesCityPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let countryCode: String
    let onSave: (ResolvedPlace) -> Void
    @State private var cityName = ""
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var locationService = LocationService()

    private var countryName: String { locale.localizedString(forRegionCode: countryCode) ?? countryCode }

    var body: some View {
        NavigationStack {
            Form {
                Section(appLocalized("addplaces.countryPicker.selectedCountry", locale: locale)) {
                    HStack { Text(flagEmoji).font(.title2); Text(countryName) }
                }
                Section(appLocalized("addplaces.countryPicker.citySection", locale: locale)) {
                    TextField(appLocalized("addplaces.countryPicker.cityPlaceholder", locale: locale), text: $cityName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    Button {
                        Task { await searchCity() }
                    } label: {
                        HStack {
                            Text(appLocalized("addplaces.countryPicker.cityAction", locale: locale))
                            Spacer()
                            if isSearching { ProgressView().controlSize(.small) }
                        }
                    }
                    .disabled(cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                }
            }
            .navigationTitle(appLocalized("addplaces.countryPicker.cityTitle", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(appLocalized("common.cancel", locale: locale)) { dismiss() } } }
            .alert(appLocalized("addplaces.countryPicker.cityErrorTitle", locale: locale), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button(appLocalized("common.done", locale: locale), role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .presentationDetents([.medium])
    }

    private func searchCity() async {
        isSearching = true
        defer { isSearching = false }
        do {
            onSave(try await locationService.resolve(city: cityName, countryName: countryName))
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    private var flagEmoji: String {
        countryCode.uppercased().unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value).map(String.init) }.joined()
    }
}
