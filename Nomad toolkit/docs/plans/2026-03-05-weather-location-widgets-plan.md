# Weather Location + Widgets Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add location-based weather with city search, migrate persistence to App Group, and create iOS home screen widgets for all 6 card types.

**Architecture:** Monolithic widget extension (Approach A) — shared file membership between main app and widget targets. SharedDefaults wrapper for App Group UserDefaults. CitySelectionView modeled after CurrencySelectionView.

**Tech Stack:** SwiftUI, WidgetKit, AppIntents (iOS 17), CoreLocation, Open-Meteo API

---

## Phase 1: SharedDefaults Foundation

### Task 1: Create SharedDefaults helper

**Files:**
- Create: `Nomad toolkit/Nomad toolkit/Utilities/SharedDefaults.swift`

**Step 1: Create the SharedDefaults wrapper**

```swift
import Foundation

enum SharedDefaults {
    static let suiteName = "group.vvstudio.co.Nomad-toolkit"

    static var store: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project "Nomad toolkit/Nomad toolkit.xcodeproj" -scheme "Nomad toolkit" -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Nomad toolkit/Nomad toolkit/Utilities/SharedDefaults.swift"
git commit -m "feat: add SharedDefaults helper for App Group container"
```

---

### Task 2: Migrate UserViewModel to SharedDefaults

**Files:**
- Modify: `Nomad toolkit/Nomad toolkit/ViewModels/UserViewModel.swift`

**Step 1: Replace all `UserDefaults.standard` with `SharedDefaults.store`**

Every occurrence of `UserDefaults.standard` in UserViewModel.swift (lines 24, 42-48, 52-54, 62-64) should become `SharedDefaults.store`. There are 10 occurrences total.

**Step 2: Build to verify**

Run: `xcodebuild -project "Nomad toolkit/Nomad toolkit.xcodeproj" -scheme "Nomad toolkit" -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Nomad toolkit/Nomad toolkit/ViewModels/UserViewModel.swift"
git commit -m "refactor: migrate UserViewModel to SharedDefaults"
```

---

### Task 3: Migrate CurrencyViewModel to SharedDefaults

**Files:**
- Modify: `Nomad toolkit/Nomad toolkit/ViewModels/CurrencyViewModel.swift`

**Step 1: Replace all `UserDefaults.standard` with `SharedDefaults.store`**

Lines 88, 93, 102, 105 — 4 occurrences.

**Step 2: Build to verify**

**Step 3: Commit**

```bash
git add "Nomad toolkit/Nomad toolkit/ViewModels/CurrencyViewModel.swift"
git commit -m "refactor: migrate CurrencyViewModel to SharedDefaults"
```

---

### Task 4: Migrate TranslationViewModel to SharedDefaults

**Files:**
- Modify: `Nomad toolkit/Nomad toolkit/ViewModels/TranslationViewModel.swift`

**Step 1: Replace all `UserDefaults.standard` with `SharedDefaults.store`**

Lines 89, 93, 102, 105 — 4 occurrences.

**Step 2: Build to verify**

**Step 3: Commit**

```bash
git add "Nomad toolkit/Nomad toolkit/ViewModels/TranslationViewModel.swift"
git commit -m "refactor: migrate TranslationViewModel to SharedDefaults"
```

---

### Task 5: Migrate TimeZoneViewModel to SharedDefaults

**Files:**
- Modify: `Nomad toolkit/Nomad toolkit/ViewModels/TimeZoneViewModel.swift`

**Step 1: Replace all `UserDefaults.standard` with `SharedDefaults.store`**

Lines 75, 93 — 2 occurrences.

**Step 2: Build to verify**

**Step 3: Commit**

```bash
git add "Nomad toolkit/Nomad toolkit/ViewModels/TimeZoneViewModel.swift"
git commit -m "refactor: migrate TimeZoneViewModel to SharedDefaults"
```

---

### Task 6: Add persistence to PackingListViewModel

**Files:**
- Modify: `Nomad toolkit/Nomad toolkit/ViewModels/PackingListViewModel.swift`

**Step 1: Add load/save methods using SharedDefaults**

PackingListViewModel currently does NOT persist `selectedIDs`. Add persistence:

```swift
private let storageKey = "packingSelectedIDs"

init() {
    loadFromStorage()
}

private func loadFromStorage() {
    if let saved = SharedDefaults.store.array(forKey: storageKey) as? [String] {
        selectedIDs = Set(saved)
    }
}

private func saveToStorage() {
    SharedDefaults.store.set(Array(selectedIDs), forKey: storageKey)
}
```

**Step 2: Call `saveToStorage()` at the end of `toggle(_:)` method**

**Step 3: Build to verify**

**Step 4: Commit**

```bash
git add "Nomad toolkit/Nomad toolkit/ViewModels/PackingListViewModel.swift"
git commit -m "feat: persist packing list selections to SharedDefaults"
```

---

### Task 7: Migrate HomeView passportStayDays to SharedDefaults

**Files:**
- Modify: `Nomad toolkit/Nomad toolkit/Views/HomeView.swift`

**Step 1: Replace `UserDefaults.standard` with `SharedDefaults.store`**

Lines 180, 189, 191 — 3 occurrences referencing `"passportStayDays"`.

**Step 2: Build to verify**

**Step 3: Commit**

```bash
git add "Nomad toolkit/Nomad toolkit/Views/HomeView.swift"
git commit -m "refactor: migrate HomeView passportStayDays to SharedDefaults"
```

---

### Task 8: Persist last weather to SharedDefaults

**Files:**
- Modify: `Nomad toolkit/Nomad toolkit/ViewModels/WeatherViewModel.swift`

**Step 1: Add weather persistence**

After weather is fetched successfully (lines 65 and 89 where `self.currentWeather = weather`), save it:

```swift
if let encoded = try? JSONEncoder().encode(weather) {
    SharedDefaults.store.set(encoded, forKey: "lastWeather")
}
```

**Step 2: On init, load cached weather before fetching fresh data**

Replace `loadDefaultWeather()` call (line 28) with:

```swift
if let data = SharedDefaults.store.data(forKey: "lastWeather"),
   let cached = try? JSONDecoder().decode(Weather.self, from: data) {
    self.currentWeather = cached
}
```

**Step 3: Build to verify**

**Step 4: Commit**

```bash
git add "Nomad toolkit/Nomad toolkit/ViewModels/WeatherViewModel.swift"
git commit -m "feat: persist last weather data to SharedDefaults"
```

---

## Phase 2: Location Permission + City Search

### Task 9: Fix Info.plist location permission

**Files:**
- Modify: `Nomad toolkit/Nomad toolkit.xcodeproj/project.pbxproj`

**Step 1: Add NSLocationWhenInUseUsageDescription**

In the project.pbxproj, find the build settings section with `INFOPLIST_KEY_NSCameraUsageDescription` and add nearby:

```
INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Nomad toolkit uses your location to show local weather";
```

This must be added to BOTH the Debug and Release build configurations for the main app target.

**Step 2: Build to verify**

**Step 3: Commit**

```bash
git add "Nomad toolkit/Nomad toolkit.xcodeproj/project.pbxproj"
git commit -m "fix: add NSLocationWhenInUseUsageDescription to enable location services"
```

---

### Task 10: Create CitySelectionView

**Files:**
- Create: `Nomad toolkit/Nomad toolkit/Views/CitySelectionView.swift`

**Step 1: Create the city search view**

Model after CurrencySelectionView. Key elements:
- `@Binding var isPresented: Bool`
- `@State private var searchText = ""`
- `@State private var searchResults: [GeocodingResult] = []`
- `var onCitySelected: (String, Double, Double, String) -> Void` — callback with cityName, lat, lon, countryCode
- Debounced search (~300ms) calling Open-Meteo geocoding API
- NavigationStack with List of results
- Each row: city name, region, country
- Toolbar with Done button

```swift
import SwiftUI

struct GeocodingResult: Identifiable, Codable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String? // region/state
    let countryCode: String?

    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, country, admin1
        case countryCode = "country_code"
    }
}

struct GeocodingResponse: Codable {
    let results: [GeocodingResult]?
}

struct CitySelectionView: View {
    @Binding var isPresented: Bool
    var onCitySelected: (String, Double, Double, String) -> Void

    @State private var searchText = ""
    @State private var searchResults: [GeocodingResult] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                ForEach(searchResults) { result in
                    Button {
                        onCitySelected(
                            result.name,
                            result.latitude,
                            result.longitude,
                            result.countryCode ?? ""
                        )
                        isPresented = false
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                            Text([result.admin1, result.country]
                                .compactMap { $0 }
                                .joined(separator: ", "))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .searchable(text: $searchText, prompt: Text("Search city"))
            .navigationTitle("Select City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                    searchResults = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                    guard !Task.isCancelled else { return }
                    await performSearch(query: newValue)
                }
            }
        }
    }

    private func performSearch(query: String) async {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=10&language=en") else {
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GeocodingResponse.self, from: data)
            await MainActor.run {
                searchResults = response.results ?? []
            }
        } catch {
            // Silently fail — user can keep typing
        }
    }
}
```

**Step 2: Build to verify**

**Step 3: Commit**

```bash
git add "Nomad toolkit/Nomad toolkit/Views/CitySelectionView.swift"
git commit -m "feat: add CitySelectionView with Open-Meteo geocoding search"
```

---

### Task 11: Update WeatherViewModel for city selection

**Files:**
- Modify: `Nomad toolkit/Nomad toolkit/ViewModels/WeatherViewModel.swift`

**Step 1: Add city selection state and methods**

Add published properties:
```swift
@MainActor @Published var selectedCity: String?
@MainActor @Published var showCitySelection = false
@MainActor @Published var locationDenied = false
```

**Step 2: Update init to check location auth and load saved city**

In `setupLocationManager()`, also subscribe to `authorizationStatus`:
```swift
locationManager.$authorizationStatus
    .compactMap { $0 }
    .receive(on: DispatchQueue.main)
    .sink { [weak self] status in
        if status == .denied || status == .restricted {
            self?.locationDenied = true
            // If no saved city, show selection
            if self?.selectedCity == nil {
                self?.showCitySelection = true
            }
        }
    }
    .store(in: &cancellables)
```

Load saved city from SharedDefaults in init:
```swift
self.selectedCity = SharedDefaults.store.string(forKey: "selectedCity")
if let city = self.selectedCity {
    self.loadWeather(for: city)
} else {
    self.loadDefaultWeather()
}
```

**Step 3: Add method for selecting a city by coordinates**

```swift
@MainActor
func selectCity(name: String, latitude: Double, longitude: Double, countryCode: String) {
    selectedCity = name
    SharedDefaults.store.set(name, forKey: "selectedCity")
    isLoading = true
    Task {
        do {
            let weather = try await weatherService.fetchWeather(
                latitude: latitude,
                longitude: longitude,
                cityName: name,
                countryCode: countryCode
            )
            self.currentWeather = weather
            if let encoded = try? JSONEncoder().encode(weather) {
                SharedDefaults.store.set(encoded, forKey: "lastWeather")
            }
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}
```

**Step 4: Build to verify**

**Step 5: Commit**

```bash
git add "Nomad toolkit/Nomad toolkit/ViewModels/WeatherViewModel.swift"
git commit -m "feat: add city selection support to WeatherViewModel"
```

---

### Task 12: Update WeatherCardView with city change button

**Files:**
- Modify: `Nomad toolkit/Nomad toolkit/Views/WeatherCardView.swift`

**Step 1: Add a city edit button overlay**

Add a small `location.magnifyingglass` icon button on the weather card that opens `CitySelectionView` as a sheet. Place it in the top-left area near the weather icon, or as a tap gesture on the city name text.

On the city name text (line 52), wrap it with a Button or add `.onTapGesture` that sets `viewModel.showCitySelection = true`.

**Step 2: Add the sheet modifier**

At the bottom of the ZStack (before `.clipShape`), add:
```swift
.sheet(isPresented: $viewModel.showCitySelection) {
    CitySelectionView(isPresented: $viewModel.showCitySelection) { name, lat, lon, countryCode in
        viewModel.selectCity(name: name, latitude: lat, longitude: lon, countryCode: countryCode)
    }
}
```

**Step 3: Handle denied state**

When `viewModel.locationDenied && viewModel.currentWeather == nil`, show a "Select City" prompt instead of ProgressView:
```swift
} else if viewModel.locationDenied {
    VStack {
        Image(systemName: "location.slash")
            .font(.system(size: 32))
            .foregroundColor(.white)
        Text("Tap to select a city")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onTapGesture {
        viewModel.showCitySelection = true
    }
```

**Step 4: Build to verify**

**Step 5: Commit**

```bash
git add "Nomad toolkit/Nomad toolkit/Views/WeatherCardView.swift"
git commit -m "feat: add city selection UI to WeatherCardView"
```

---

## Phase 3: Widget Extension

### Task 13: Create widget extension target (MANUAL — Xcode required)

**This task must be done in Xcode GUI:**

1. Open project in Xcode
2. File → New → Target → Widget Extension
3. Name: `NomadWidgets`
4. Uncheck "Include Configuration App Intent" (we'll add our own)
5. Deployment target: iOS 17.0
6. In project settings → both targets → Signing & Capabilities → add "App Groups" with identifier `group.vvstudio.co.Nomad-toolkit`
7. Add shared source files to widget target membership:
   - `Utilities/SharedDefaults.swift`
   - `Models/Weather.swift`
   - `Models/TimeZoneItem.swift`
   - `Models/Currency.swift`
   - `Models/Language.swift`
   - `Services/WeatherService.swift`
8. Build both targets to verify

**Commit:**

```bash
git add -A
git commit -m "feat: add NomadWidgets extension target with App Group"
```

---

### Task 14: Create WidgetBundle entry point

**Files:**
- Modify: `NomadWidgets/NomadWidgets.swift` (auto-generated by Xcode, replace content)

**Step 1: Create the widget bundle**

```swift
import WidgetKit
import SwiftUI

@main
struct NomadWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WeatherWidget()
        TimeZoneWidget()
        CurrencyWidget()
        TranslationWidget()
        PackingListWidget()
        PassportDaysWidget()
    }
}
```

**Step 2: Build widget target to verify (will fail until individual widgets exist — that's expected)**

---

### Task 15: Weather widget

**Files:**
- Create: `NomadWidgets/WeatherWidget.swift`

**Step 1: Create weather widget**

```swift
import WidgetKit
import SwiftUI

struct WeatherEntry: TimelineEntry {
    let date: Date
    let weather: Weather?
}

struct WeatherProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: .now, weather: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        let weather = loadCachedWeather()
        completion(WeatherEntry(date: .now, weather: weather))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        Task {
            let weather = await fetchOrLoadWeather()
            let entry = WeatherEntry(date: .now, weather: weather)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func loadCachedWeather() -> Weather? {
        guard let data = SharedDefaults.store.data(forKey: "lastWeather") else { return nil }
        return try? JSONDecoder().decode(Weather.self, from: data)
    }

    private func fetchOrLoadWeather() async -> Weather? {
        // Try fetching fresh weather for saved city
        if let cityName = SharedDefaults.store.string(forKey: "selectedCity") {
            let service = WeatherService()
            return try? await service.fetchWeather(for: cityName)
        }
        return loadCachedWeather()
    }
}

struct WeatherWidgetView: View {
    let entry: WeatherEntry

    var body: some View {
        if let weather = entry.weather {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: weather.conditionIconCode)
                        .font(.system(size: 20))
                        .symbolRenderingMode(.multicolor)
                    Spacer()
                    Text("\(Int(weather.temperatureC))°")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                Spacer()
                Text(weather.cityName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(weather.conditionText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if let aqi = weather.airQualityIndex {
                    Text("AQI \(aqi)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        } else {
            VStack {
                Image(systemName: "cloud.sun")
                    .font(.system(size: 24))
                Text("Open app to setup")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
        }
    }
}

struct WeatherWidget: Widget {
    let kind = "WeatherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherProvider()) { entry in
            WeatherWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weather")
        .description("Current weather for your city")
        .supportedFamilies([.systemSmall])
    }
}
```

**Step 2: Build widget target to verify**

**Step 3: Commit**

```bash
git add "NomadWidgets/WeatherWidget.swift"
git commit -m "feat: add Weather widget"
```

---

### Task 16: TimeZone widget

**Files:**
- Create: `NomadWidgets/TimeZoneWidget.swift`

**Step 1: Create timezone widget**

```swift
import WidgetKit
import SwiftUI

struct TimeZoneEntry: TimelineEntry {
    let date: Date
    let timeZones: [TimeZoneItem]
}

struct TimeZoneProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimeZoneEntry {
        TimeZoneEntry(date: .now, timeZones: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (TimeZoneEntry) -> Void) {
        completion(TimeZoneEntry(date: .now, timeZones: loadTimeZones()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimeZoneEntry>) -> Void) {
        let zones = loadTimeZones()
        let entry = TimeZoneEntry(date: .now, timeZones: zones)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadTimeZones() -> [TimeZoneItem] {
        guard let data = SharedDefaults.store.data(forKey: "savedTimeZones"),
              let zones = try? JSONDecoder().decode([TimeZoneItem].self, from: data) else {
            return []
        }
        return Array(zones.prefix(4))
    }
}

struct TimeZoneWidgetView: View {
    let entry: TimeZoneEntry

    var body: some View {
        if entry.timeZones.isEmpty {
            VStack {
                Image(systemName: "clock")
                    .font(.system(size: 24))
                Text("Open app to add\ntime zones")
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.timeZones) { zone in
                    HStack {
                        Text(zone.cityName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text(timeString(for: zone))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                }
            }
            .padding()
        }
    }

    private func timeString(for zone: TimeZoneItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: zone.timeZoneIdentifier)
        return formatter.string(from: entry.date)
    }
}

struct TimeZoneWidget: Widget {
    let kind = "TimeZoneWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeZoneProvider()) { entry in
            TimeZoneWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Time Zones")
        .description("Your saved time zones at a glance")
        .supportedFamilies([.systemSmall])
    }
}
```

**Step 2: Build and commit**

```bash
git add "NomadWidgets/TimeZoneWidget.swift"
git commit -m "feat: add TimeZone widget"
```

---

### Task 17: Currency widget (tap-to-open)

**Files:**
- Create: `NomadWidgets/CurrencyWidget.swift`

**Step 1: Create currency widget**

```swift
import WidgetKit
import SwiftUI

struct CurrencyEntry: TimelineEntry {
    let date: Date
    let fromCurrency: Currency?
    let toCurrency: Currency?
}

struct CurrencyProvider: TimelineProvider {
    func placeholder(in context: Context) -> CurrencyEntry {
        CurrencyEntry(date: .now, fromCurrency: nil, toCurrency: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrencyEntry) -> Void) {
        let (from, to) = loadCurrencies()
        completion(CurrencyEntry(date: .now, fromCurrency: from, toCurrency: to))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrencyEntry>) -> Void) {
        let (from, to) = loadCurrencies()
        let entry = CurrencyEntry(date: .now, fromCurrency: from, toCurrency: to)
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func loadCurrencies() -> (Currency?, Currency?) {
        let from: Currency? = {
            guard let data = SharedDefaults.store.data(forKey: "lastFromCurrency") else { return nil }
            return try? JSONDecoder().decode(Currency.self, from: data)
        }()
        let to: Currency? = {
            guard let data = SharedDefaults.store.data(forKey: "lastToCurrency") else { return nil }
            return try? JSONDecoder().decode(Currency.self, from: data)
        }()
        return (from, to)
    }
}

struct CurrencyWidgetView: View {
    let entry: CurrencyEntry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "dollarsign.arrow.circlepath")
                .font(.system(size: 24))
                .foregroundStyle(.blue)

            if let from = entry.fromCurrency, let to = entry.toCurrency {
                Text("\(from.id) → \(to.id)")
                    .font(.system(size: 15, weight: .semibold))
            } else {
                Text("Currency")
                    .font(.system(size: 15, weight: .semibold))
            }

            Text("Tap to convert")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .widgetURL(URL(string: "nomadkit://currency"))
    }
}

struct CurrencyWidget: Widget {
    let kind = "CurrencyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrencyProvider()) { entry in
            CurrencyWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Currency Converter")
        .description("Tap to open currency converter")
        .supportedFamilies([.systemSmall])
    }
}
```

**Step 2: Build and commit**

```bash
git add "NomadWidgets/CurrencyWidget.swift"
git commit -m "feat: add Currency widget (tap-to-open)"
```

---

### Task 18: Translation widget (tap-to-open)

**Files:**
- Create: `NomadWidgets/TranslationWidget.swift`

**Step 1: Create translation widget**

Same pattern as Currency — shows last-used language pair, taps to open app.

```swift
import WidgetKit
import SwiftUI

struct TranslationEntry: TimelineEntry {
    let date: Date
    let fromLanguage: Language?
    let toLanguage: Language?
}

struct TranslationProvider: TimelineProvider {
    func placeholder(in context: Context) -> TranslationEntry {
        TranslationEntry(date: .now, fromLanguage: nil, toLanguage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TranslationEntry) -> Void) {
        let (from, to) = loadLanguages()
        completion(TranslationEntry(date: .now, fromLanguage: from, toLanguage: to))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TranslationEntry>) -> Void) {
        let (from, to) = loadLanguages()
        let entry = TranslationEntry(date: .now, fromLanguage: from, toLanguage: to)
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func loadLanguages() -> (Language?, Language?) {
        let from: Language? = {
            guard let data = SharedDefaults.store.data(forKey: "lastFromLanguage") else { return nil }
            return try? JSONDecoder().decode(Language.self, from: data)
        }()
        let to: Language? = {
            guard let data = SharedDefaults.store.data(forKey: "lastToLanguage") else { return nil }
            return try? JSONDecoder().decode(Language.self, from: data)
        }()
        return (from, to)
    }
}

struct TranslationWidgetView: View {
    let entry: TranslationEntry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 24))
                .foregroundStyle(.purple)

            if let from = entry.fromLanguage, let to = entry.toLanguage {
                Text("\(from.name) → \(to.name)")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("Translation")
                    .font(.system(size: 15, weight: .semibold))
            }

            Text("Tap to translate")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .widgetURL(URL(string: "nomadkit://translation"))
    }
}

struct TranslationWidget: Widget {
    let kind = "TranslationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TranslationProvider()) { entry in
            TranslationWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Translation")
        .description("Tap to open translator")
        .supportedFamilies([.systemSmall])
    }
}
```

**Step 2: Build and commit**

```bash
git add "NomadWidgets/TranslationWidget.swift"
git commit -m "feat: add Translation widget (tap-to-open)"
```

---

### Task 19: Packing List interactive widget (iOS 17)

**Files:**
- Create: `NomadWidgets/PackingListWidget.swift`

**Step 1: Create the AppIntent for toggling items**

```swift
import WidgetKit
import SwiftUI
import AppIntents

struct TogglePackingItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Packing Item"

    @Parameter(title: "Item ID")
    var itemID: String

    func perform() async throws -> some IntentResult {
        var selected = Set(SharedDefaults.store.array(forKey: "packingSelectedIDs") as? [String] ?? [])
        if selected.contains(itemID) {
            selected.remove(itemID)
        } else {
            selected.insert(itemID)
        }
        SharedDefaults.store.set(Array(selected), forKey: "packingSelectedIDs")
        return .result()
    }
}
```

**Step 2: Create the widget**

```swift
struct PackingEntry: TimelineEntry {
    let date: Date
    let items: [(id: String, title: String, isSelected: Bool)]
}

struct PackingProvider: TimelineProvider {
    // Hardcoded to match PackingListViewModel
    static let allItems: [(id: String, title: String)] = [
        ("packing_laptop", "Laptop"),
        ("packing_powerbank", "Power Bank"),
        ("packing_headphones", "Headphones"),
        ("packing_wallet", "Wallet"),
        ("packing_sim", "Sim Card"),
        ("packing_shoes", "Shoes")
    ]

    func placeholder(in context: Context) -> PackingEntry {
        PackingEntry(date: .now, items: Self.allItems.map { ($0.id, $0.title, false) })
    }

    func getSnapshot(in context: Context, completion: @escaping (PackingEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PackingEntry>) -> Void) {
        completion(Timeline(entries: [loadEntry()], policy: .never))
    }

    private func loadEntry() -> PackingEntry {
        let selected = Set(SharedDefaults.store.array(forKey: "packingSelectedIDs") as? [String] ?? [])
        let items = Self.allItems.map { ($0.id, $0.title, selected.contains($0.id)) }
        return PackingEntry(date: .now, items: items)
    }
}

struct PackingListWidgetView: View {
    let entry: PackingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Packing List")
                .font(.system(size: 13, weight: .semibold))
                .padding(.bottom, 2)

            ForEach(entry.items, id: \.id) { item in
                Button(intent: TogglePackingItemIntent(itemID: item.id)) {
                    HStack(spacing: 8) {
                        Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(item.isSelected ? .green : .secondary)
                        Text(item.title)
                            .font(.system(size: 13))
                            .strikethrough(item.isSelected)
                            .foregroundStyle(item.isSelected ? .secondary : .primary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

struct PackingListWidget: Widget {
    let kind = "PackingListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PackingProvider()) { entry in
            PackingListWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Packing List")
        .description("Check off your packing items")
        .supportedFamilies([.systemMedium])
    }
}
```

Note: `TogglePackingItemIntent` needs an `init` that sets the parameter:
```swift
init(itemID: String) {
    self.itemID = itemID
}

init() {}
```

**Step 3: Build and commit**

```bash
git add "NomadWidgets/PackingListWidget.swift"
git commit -m "feat: add interactive Packing List widget with AppIntent"
```

---

### Task 20: Passport Days widget

**Files:**
- Create: `NomadWidgets/PassportDaysWidget.swift`

**Step 1: Create passport days widget**

```swift
import WidgetKit
import SwiftUI

struct PassportEntry: TimelineEntry {
    let date: Date
    let currentDay: Int
    let stayDays: Int?
    let userName: String?
}

struct PassportProvider: TimelineProvider {
    func placeholder(in context: Context) -> PassportEntry {
        PassportEntry(date: .now, currentDay: 1, stayDays: nil, userName: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PassportEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PassportEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> PassportEntry {
        let store = SharedDefaults.store
        let loginDate = store.object(forKey: "loginDate") as? Date
        let currentDay: Int
        if let loginDate {
            let days = Calendar.current.dateComponents([.day], from: loginDate, to: Date()).day ?? 0
            currentDay = max(1, days + 1)
        } else {
            currentDay = 1
        }
        let stayDays = store.object(forKey: "passportStayDays") as? Int
        let userName = store.string(forKey: "userName")
        return PassportEntry(date: .now, currentDay: currentDay, stayDays: stayDays, userName: userName)
    }
}

struct PassportDaysWidgetView: View {
    let entry: PassportEntry

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 20))
                .foregroundStyle(.orange)

            Text("Day \(entry.currentDay)")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            if let stayDays = entry.stayDays {
                let remaining = max(0, stayDays - entry.currentDay)
                Text("\(remaining) days left")
                    .font(.system(size: 12))
                    .foregroundStyle(remaining <= 3 ? .red : .secondary)
            }

            if let name = entry.userName, !name.isEmpty {
                Text(name)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PassportDaysWidget: Widget {
    let kind = "PassportDaysWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PassportProvider()) { entry in
            PassportDaysWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Passport Days")
        .description("Track your travel day count")
        .supportedFamilies([.systemSmall])
    }
}
```

**Step 2: Build and commit**

```bash
git add "NomadWidgets/PassportDaysWidget.swift"
git commit -m "feat: add Passport Days widget"
```

---

## Phase 4: Deep Linking

### Task 21: Add deep link handling to main app

**Files:**
- Modify: `Nomad toolkit/Nomad toolkit/Nomad_toolkitApp.swift`
- Modify: `Nomad toolkit/Nomad toolkit/Views/HomeView.swift`

**Step 1: Add URL handling to app entry point**

In `Nomad_toolkitApp.swift`, add an `@State` for the deep link destination and handle `onOpenURL`:

```swift
@State private var deepLinkDestination: String?

// Inside WindowGroup, after .preferredColorScheme(.light):
.onOpenURL { url in
    deepLinkDestination = url.host()
}
.environment(\.deepLinkDestination, deepLinkDestination)
```

**Step 2: Create a simple environment key**

Add to `Nomad_toolkitApp.swift` or a new `Utilities/DeepLink.swift`:

```swift
private struct DeepLinkDestinationKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var deepLinkDestination: String? {
        get { self[DeepLinkDestinationKey.self] }
        set { self[DeepLinkDestinationKey.self] = newValue }
    }
}
```

**Step 3: In HomeView, read the environment and scroll to the right card**

Add `@Environment(\.deepLinkDestination) var deepLinkDestination` and use `ScrollViewReader` to scroll to the relevant card ID on change.

Add `.id("currency")` to `CurrencyConverterCardView` and `.id("translation")` to `TranslationCardView`.

```swift
.onChange(of: deepLinkDestination) { _, destination in
    guard let destination else { return }
    withAnimation {
        proxy.scrollTo(destination, anchor: .top)
    }
}
```

**Step 4: Register URL scheme**

In Xcode: Target → Info → URL Types → add scheme `nomadkit`.

Or in project.pbxproj, add to INFOPLIST build settings:
```
INFOPLIST_KEY_CFBundleURLTypes = "([{CFBundleURLSchemes = (nomadkit);}])";
```

**Step 5: Build to verify**

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add deep link handling for widget tap-to-open"
```

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 | 1-8 | SharedDefaults foundation + migrate all persistence |
| 2 | 9-12 | Location permission fix + city search |
| 3 | 13-20 | Widget extension with all 6 widgets |
| 4 | 21 | Deep linking for tap-to-open widgets |

**Total: 21 tasks, ~4 phases**
