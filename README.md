# Remind Anything

Capture anything on your screen (a browser tab, an app window, or a region),
attach a note, and get reminded later — with enough context (URL, window,
timestamp) to instantly pick up where you left off.

This is an implementation of [`docs/design.md`](docs/design.md) as a native
macOS menu-bar app.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9+ toolchain / Xcode 15+

> The design targets macOS 13+, but this build uses **SwiftData** (macOS 14+)
> for the store, so the minimum is raised to macOS 14.

## Build & Run

```bash
# Compile the package
swift build

# Produce a runnable, ad-hoc-signed .app bundle in ./dist
./Scripts/build_app.sh
open "dist/Remind Anything.app"
```

On first launch you'll see an onboarding window explaining the permissions the
app needs (Screen Recording, Accessibility, Notifications). Grant them, then use
the menu-bar icon or a global hotkey to capture.

### Default hotkeys

| Shortcut | Action |
|---|---|
| ⌥⇧2 | Capture **Region** (default fast path) |
| ⌥⇧1 | Capture **Window** (frontmost) |
| ⌥⇧3 | Capture **Full Screen** (display under cursor) |

All three are re-bindable in **Preferences → Shortcuts**.

## How it maps to the design

| Design component | Source |
|---|---|
| Menu Bar App | `App/RemindAnythingApp.swift`, `UI/MenuContent.swift` |
| Hotkey Manager | `Hotkeys/HotkeyManager.swift` (Carbon `RegisterEventHotKey`) |
| Capture Engine | `Capture/CaptureEngine.swift` (ScreenCaptureKit) |
| Region overlay | `Capture/RegionSelectionController.swift` |
| Context Collector | `Context/ContextCollector.swift`, `Context/BrowserContext.swift` |
| Compose UI | `UI/ComposePanelController.swift` (floating `NSPanel`) + `UI/ComposeView.swift` |
| Store | `Store/Store.swift` + `Models/Reminder.swift` (SwiftData) + `Support/ImageStore.swift` (PNGs on disk) |
| Scheduler | `Scheduler/NotificationScheduler.swift` (`UNUserNotificationCenter`) |
| Library UI | `UI/LibraryView.swift` |
| Preferences / Onboarding | `UI/PreferencesView.swift`, `UI/OnboardingView.swift` |
| Login item / notification actions | `App/AppDelegate.swift`, `App/AppSettings.swift` (`SMAppService`) |

### Capture flow (as implemented)

1. Hotkey / menu triggers `CaptureCoordinator`.
2. **Context is collected first** (`ContextCollector`) — while the source app is
   still frontmost — so a region crop of a Chrome tab still records that tab's
   URL. Browser URLs come from AppleScript (`BrowserContext`); window titles from
   Accessibility.
3. Pixels are grabbed silently via `SCScreenshotManager` (region overlay is
   dismissed before the grab so it isn't captured).
4. The floating compose panel appears with the thumbnail, editable context
   chips, a note field, and an **At / In / Every** schedule picker.
5. On save: PNG + thumbnail are written to
   `~/Library/Application Support/RemindAnything/captures/`, a `Reminder` row is
   inserted into SwiftData, and a `UNNotificationRequest` is scheduled.

### Notifications

Reminders fire via `UNUserNotificationCenter` with **Open / Snooze / Done**
actions. "Open" reopens the captured URL (or reveals the screenshot in Finder if
there was no URL). The app registers as a **login item** (`SMAppService`) so
reminders fire even when browsers are closed, and re-reconciles pending
notifications on launch.

## Data & privacy

- **100% local.** No network calls. Images and the SwiftData store stay on disk.
- Metadata lives in `RemindAnything.store`; screenshots + thumbnails are files
  under `captures/`.

## Distribution

`Scripts/build_app.sh --sign "Developer ID Application: NAME (TEAMID)"` produces
a hardened-runtime signed bundle ready for notarization and packaging into a DMG
/ Homebrew Cask, per §8 and §10 (M5) of the design.

## Project layout

```
Sources/RemindAnything/
├── App/          App entry, delegate, settings
├── Models/       Reminder + enums
├── Store/        SwiftData container
├── Capture/      ScreenCaptureKit engine, region overlay, coordinator, draft
├── Context/      Browser URL + window/app context
├── Hotkeys/      Carbon global hotkeys
├── Scheduler/    UserNotifications
├── Support/      Paths, image store, permissions
└── UI/           Menu, compose panel, library, preferences, onboarding
App/              Info.plist + entitlements (for bundling)
Scripts/          build_app.sh
```
