# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build System

This project uses **XcodeGen** to generate the `.xcodeproj` from `project.yml`. After modifying `project.yml`, regenerate the project:

```bash
xcodegen generate
```

Dependencies are managed via **Swift Package Manager** (no CocoaPods). The only external dependency is `GoogleMobileAds` (v12.0+).

## Building

```bash
# Build
xcodebuild -scheme TVSharedLists build

# Build for simulator
xcodebuild -scheme TVSharedLists -destination 'generic/platform=iOS Simulator' build
```

**Local setup:** `TVSharedLists/Secrets.swift` is gitignored. Copy `Secrets.swift.template` to `TVSharedLists/Secrets.swift` and fill in your AdMob IDs from the AdMob console.

## CI/CD

Uses **Xcode Cloud** (not GitHub Actions). The pre-build script `ci_scripts/ci_pre_xcodebuild.sh` auto-generates `Secrets.swift` and patches `Info.plist` from two Xcode Cloud environment secrets: `ADMOB_APP_ID` and `ADMOB_BANNER_ID`.

## Architecture

**Pattern:** MVVM with a service layer. No Redux or centralized state store — the app is intentionally simple.

- `Models/TVShow.swift` — Core `Codable` model. `tvMazeId` is `-1` for manually-entered shows. Rating is `0–5` Int. Thumbs is `"up"/"down"/"none"` String.
- `ViewModels/TVShowViewModel.swift` — `@MainActor ObservableObject` that owns all app state (`shows`, `isLoading`, `errorMessage`). Delegates persistence to `TVShowStore`.
- `Services/TVShowStore.swift` — Persists to `~/Documents/tvshows.json` as pretty-printed JSON with ISO8601 dates. No database, no iCloud sync.
- `Services/TVMazeService.swift` — Searches the TVMaze REST API with 350ms debounce and task cancellation. Returns top 10 results. Poster URLs are forced to HTTPS.
- `Services/CSVService.swift` — RFC 4180 CSV parser for import/export. Supports 9-column (legacy) and 10-column formats. Duplicate detection uses `tvMazeId` first, then case-insensitive title matching. Import has two modes: "Replace All" and "Merge".
- `Views/ContentView.swift` — Root `TabView` with 3 tabs: Shows, Add Show, Import/Export.
- `Components/BannerAdView.swift` — `UIViewRepresentable` wrapping `GADBannerView` for AdMob banner ads.

## Key Constraints

- Deployment target: **iOS 16.0**
- No tests exist currently.
- No linter configuration.
- `GoogleService-Info.plist` is gitignored — Firebase is not used despite the gitignore entry (leftover from an earlier iteration).
