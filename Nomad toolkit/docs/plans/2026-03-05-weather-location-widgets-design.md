# Design: Location-Based Weather + Home Screen Widgets

**Date:** 2026-03-05
**Status:** Approved

## Overview

Two features for Nomad toolkit:
1. Fix location-based weather and add manual city search when permission is denied
2. Add iOS home screen widgets for all 6 card types

## Feature 1: Location-Based Weather + City Search

### Info.plist Fix
Add `NSLocationWhenInUseUsageDescription` to project build settings: *"Nomad toolkit uses your location to show local weather"*

### Location Permission Flow
1. On first launch, `WeatherViewModel` requests location (existing behavior)
2. **Permission granted** -> fetch weather for GPS coordinates (existing, now works with plist fix)
3. **Permission denied** -> show weather card with "Select City" prompt; no fallback to Kuala Lumpur

### CitySelectionView (new)
- Modeled after `CurrencySelectionView` — sheet with search field and scrollable results
- Uses Open-Meteo geocoding API (`geocoding-api.open-meteo.com/v1/search`) with ~300ms debounce
- Each result shows: city name, country, region/state
- On selection: fetch weather, save city to shared UserDefaults
- Small location/edit icon on WeatherCardView opens the sheet (always visible, so users can override GPS)

### WeatherViewModel Changes
- Add `@Published var selectedCity: String?` persisted to shared App Group UserDefaults
- Priority: GPS location > saved city > Kuala Lumpur fallback
- Manual city pick overrides GPS until cleared or location re-enabled

## Feature 2: App Group & Shared UserDefaults Migration

### App Group
- Identifier: `group.vvstudio.co.Nomad-toolkit`
- Both main app and widget extension join this group

### SharedDefaults Helper
Simple wrapper providing `UserDefaults(suiteName: "group.vvstudio.co.Nomad-toolkit")`.

### Persisted Data (Shared Container)

| Key | Type | Widget Consumer |
|-----|------|-----------------|
| `selectedCity` | String? | Weather |
| `lastWeather` | Weather (Codable) | Weather |
| `savedTimeZones` | [TimeZoneItem] (Codable) | TimeZone |
| `lastFromCurrency` / `lastToCurrency` | String | Currency |
| `lastFromLanguage` / `lastToLanguage` | String | Translation |
| `packingListItems` | [String: Bool] | Packing List |
| `loginDate` | Date | Passport Days |
| `passportStayDays` | Int | Passport Days |
| `userName` | String | Passport Days |

### Migration Strategy
Full switch to App Group container. No dual-write, no backward compatibility.

## Feature 3: Widget Extension

### Target
- Name: `NomadWidgets`
- Deployment target: iOS 17.0
- Approach: shared file membership (models + services added to both targets)

### Widget Types

| Widget | WidgetFamily | Content | Interactivity |
|--------|-------------|---------|---------------|
| Weather | `.systemSmall` | Temp, city, condition icon, AQI | Tap opens app |
| Time Zone | `.systemSmall` | Top 3-4 saved time zones | Tap opens app |
| Currency | `.systemSmall` | Last-used pair + rate, "Tap to convert" | Tap opens app -> currency card |
| Translation | `.systemSmall` | Last-used languages, "Tap to translate" | Tap opens app -> translation card |
| Packing List | `.systemMedium` | Checklist with toggleable checkboxes | Interactive (AppIntent) |
| Passport Days | `.systemSmall` | "Day X" counter + days remaining | Tap opens app |

### Timeline Refresh
- Weather: every 30 minutes
- Time Zone: every 1 minute (local clock math, no network)
- Currency / Translation: static (reads shared UserDefaults)
- Packing List: reloads on interaction (AppIntent triggers refresh)
- Passport Days: every 1 hour

### Deep Linking
- URL scheme: `nomadkit://currency`, `nomadkit://translation`
- Currency and Translation widgets use `widgetURL` for deep linking
- App entry point handles URL to navigate to the right card

### Packing List Interactive Widget (iOS 17)
- Uses `AppIntent` + `Button` in widget view
- Each toggle updates shared UserDefaults and requests timeline reload
- Shows item name + checkbox icon (filled/empty)

## Architecture: Approach A (Shared File Membership)
- One widget extension target containing all 6 widget types
- Shared source files (models, services, SharedDefaults) added to both main app and widget targets
- `#if` guards where needed for app-only code (e.g., CLLocationManager)
- No shared framework — keeps project simple
