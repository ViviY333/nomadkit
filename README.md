# Nomadkit

A SwiftUI iOS app for digital nomads. Weather, currency conversion (fiat + crypto), translation, time zone tracking, packing checklist, and passport stay-day tracking — all on a single scrollable home screen with card-based UI.

## Features

- **Weather** — Current conditions, temperature, AQI, and rain chance based on GPS location or manual city search
- **Currency Converter** — Fiat and crypto conversion (USD, EUR, BTC, ETH, etc.) with live rates from Frankfurter and Coinbase APIs
- **Translation** — Text translation between 15 languages via MyMemory API
- **Time Zones** — Track up to 10 time zones with drag-to-reorder
- **Packing List** — Quick checklist for travel essentials (laptop, power bank, headphones, wallet, SIM card, shoes)
- **Passport Days** — Tracks how many days since you started your trip, with configurable visa stay-day warnings

### Home Screen Widgets

All features are available as iOS home screen widgets:

| Widget | Size | Behavior |
|--------|------|----------|
| Weather | Small | Live weather, refreshes every 30 min |
| Time Zones | Small | Shows top 4 saved zones, updates every minute |
| Currency | Small | Tap to open converter in app |
| Translation | Small | Tap to open translator in app |
| Packing List | Medium | Interactive — toggle items directly from home screen |
| Passport Days | Small | Day counter with remaining days |

## Requirements

- Xcode 16+
- iOS 17.0+
- No API keys required — all external APIs are free and public

## Getting Started

1. Clone the repo
2. Open `Nomad toolkit/Nomad toolkit.xcodeproj` in Xcode
3. SPM dependencies (RevenueCat) resolve automatically on first open
4. Select an iOS Simulator or your device and hit Run

```bash
# Or build from command line
xcodebuild -project "Nomad toolkit/Nomad toolkit.xcodeproj" \
  -scheme "Nomad toolkit" \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Project Structure

```
Nomad toolkit/Nomad toolkit/
  Models/          Currency, Weather, Language, TimeZoneItem
  Services/        CurrencyService, WeatherService, TranslationService, LocationManager
  ViewModels/      One per feature card (WeatherViewModel, CurrencyViewModel, etc.)
  Views/           SwiftUI views — cards, selection sheets, overlays
  Utilities/       SharedDefaults (App Group), DeepLink, Localization

Nomad toolkit/NomadWidgets/
  NomadWidgetsBundle.swift   Widget extension entry point
  WeatherWidget.swift        Weather widget
  TimeZoneWidget.swift       Time zone widget
  CurrencyWidget.swift       Currency widget (tap-to-open)
  TranslationWidget.swift    Translation widget (tap-to-open)
  PackingListWidget.swift    Interactive packing list widget
  PassportDaysWidget.swift   Passport days widget
```

## Architecture

**MVVM** with protocol-based services. Each feature card has its own `ObservableObject` ViewModel instantiated as `@StateObject` in `HomeView`.

**App flow:** `Nomad_toolkitApp` → `LoginView` (tap-to-enter splash) → `HomeView` (all cards)

**Persistence:** All state stored in App Group `UserDefaults` via `SharedDefaults.store`, shared between the main app and widget extension.

**External APIs (all free, no keys):**
- [Open-Meteo](https://open-meteo.com/) — weather, air quality, geocoding
- [Frankfurter](https://www.frankfurter.app/) — fiat exchange rates
- [Coinbase](https://api.coinbase.com/) — crypto prices
- [MyMemory](https://mymemory.translated.net/) — translation

## Conventions

- **Light mode only** — forced via `.preferredColorScheme(.light)`
- **Custom font** — InstrumentSerif (Regular + Italic) bundled in `fonts/`
- **Localization** — Manual Chinese/English via `LocalizedString` enum (checks device locale)
- **No API keys** — all services use free public endpoints
- **iOS 17 widgets** — Packing list uses `AppIntent` for interactive toggles
