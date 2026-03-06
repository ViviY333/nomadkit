# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nomad toolkit is a SwiftUI iOS app for digital nomads. It provides weather, currency conversion (fiat + crypto), translation, time zone tracking, packing checklist, and passport stay-day tracking — all on a single scrollable home screen with card-based UI.

## Build & Run

This is an Xcode project (no CocoaPods/Carthage). Open `Nomad toolkit/Nomad toolkit.xcodeproj` in Xcode.

```bash
# Build from command line
xcodebuild -project "Nomad toolkit/Nomad toolkit.xcodeproj" -scheme "Nomad toolkit" -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests (no test target exists yet)
```

**SPM dependency:** RevenueCat `purchases-ios-spm` (v5.52.0) — resolved automatically by Xcode.

## Architecture

MVVM pattern with protocol-based services. All Swift source lives under `Nomad toolkit/Nomad toolkit/`.

### Flow

`Nomad_toolkitApp` → `LoginView` (tap-to-enter splash) → `ContentView` → `HomeView` (main screen with all feature cards)

### Models
- `Currency` — fiat + crypto currency definitions with static `defaultCurrencies` list
- `Weather` — weather data including AQI and rain chance
- `Language` — translation language definitions with static `supportedLanguages` list
- `TimeZoneItem` — saved time zone entries

### Services (protocol + concrete class)
- `CurrencyService` — fetches fiat rates from Frankfurter API and crypto rates from Coinbase API (USD-based, parallel fetch)
- `WeatherService` — uses Open-Meteo geocoding + weather + air quality APIs
- `TranslationService` — uses MyMemory free translation API
- `LocationManager` — CLLocationManager wrapper for device GPS

### ViewModels (`@MainActor` published properties)
Each feature card has its own `ObservableObject` ViewModel instantiated as `@StateObject` in `HomeView`:
- `WeatherViewModel` — auto-fetches weather for GPS location, falls back to Kuala Lumpur
- `CurrencyViewModel` — currency conversion with swap, remembers last-used pair via UserDefaults
- `TranslationViewModel` — text translation with language swap, remembers last-used pair
- `TimeZoneViewModel` — manages up to 10 time zones with drag reorder, persisted to UserDefaults
- `PackingListViewModel` — hardcoded checklist items with toggle state (not persisted)
- `UserViewModel` — login state + day counter (days since first login) via UserDefaults

### Views
Cards: `WeatherCardView`, `TimeZoneCardView`, `CurrencyConverterCardView`, `TranslationCardView`, `PackingListCardView`
Selection sheets: `CurrencySelectionView`, `LanguageSelectionView`, `TimeZoneSelectionView`
Overlays: `PassportDaysInputView`, `StayDaysWarningView`

## Key Conventions

- **Light mode only** — forced via `.preferredColorScheme(.light)` in the app entry point
- **Custom font** — InstrumentSerif (Regular + Italic) bundled in `fonts/`
- **Localization** — manual Chinese/English via `LocalizedString` enum in `Utilities/Localization.swift` (checks device locale)
- **Persistence** — all state is stored in `UserDefaults` (no Core Data, no SwiftData)
- **No API keys required** — all external APIs (Frankfurter, Coinbase, Open-Meteo, MyMemory) are free/public
- **Comments are in Chinese** — the original developer wrote Chinese comments throughout the codebase
