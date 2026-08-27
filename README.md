# Nomad Kit

Nomad Kit is a native iPhone companion for digital nomads. It brings city essentials, travel-preparation checklists, city check-ins, badges, and a shareable passport into one offline-friendly SwiftUI app.

## Current scope

- **Today**: a city survival page with local conditions, work-friendly places, reminders, and common local channels.
- **Safety kit**: eight travel-preparation categories covering insurance, connectivity, payments, medicine, packing, documents, emergency details, and workspaces.
- **Passport stamps**: manual city check-ins, travel statistics, badges, and a vertical passport image for social sharing.
- **Profile and settings**: language, travel profile, saved places, and local-data management.

The v0.1 app uses bundled JSON and mock services so it remains testable without an account or network connection. Dynamic weather, exchange rates, maps, authentication, and CloudKit sync are planned for later releases.

## Requirements

- Xcode 16 or later
- iOS 17.0 or later
- macOS with an iOS Simulator, or an iPhone for device testing

## Run

1. Open `NomadKit.xcodeproj` in Xcode.
2. Select the `NomadKit` scheme and an iPhone simulator.
3. Build and run.

The scheme passes `-onboarding-reset` during development so the onboarding flow is shown after each launch. Remove that launch argument to test persisted data.

## Visa data

Residency uses the keyless, MIT-licensed [Passport Index Data](https://github.com/imorte/passport-index-data) matrix by default, with Toshiko as a secondary fallback. To enable Travel Buddy's daily-updated passport map, subscribe to its free RapidAPI plan and add `TRAVEL_BUDDY_API_KEY` under **Scheme > Run > Arguments > Environment Variables**. Results are cached per passport for seven days; the key is not stored in the repository or app bundle.

## Tests

Run the unit-test target from Xcode, or use:

```sh
xcodebuild -project NomadKit.xcodeproj \
  -scheme NomadKit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NomadKitTests \
  test CODE_SIGNING_ALLOWED=NO
```

## Repository layout

```text
NomadKit/          App source, resources, and bundled content
NomadKitTests/     Unit tests
NomadKitUITests/   UI tests
prd/               Product requirements and content research
prototype-v2/      Approved HTML interaction and visual reference
project.yml        XcodeGen project definition
```

## Content notice

Visa, insurance, health, and entry information is illustrative and must be verified against official sources, embassies, or insurers before travel.
