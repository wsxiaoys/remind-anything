# Remind Anything — v0 Implementation Status

> Status of the implementation against [`design.md`](design.md).
> This tracks what is built, how it maps to the design, and what remains.

- **Status:** v0 — feature-complete, compiles & runs locally (ad-hoc signed)
- **Platform:** macOS **14 Sonoma+** (raised from the design's 13+ because the
  store uses SwiftData)
- **Toolchain verified:** Swift 6.2 (5.9 language mode), Xcode 26, macOS 15
- **Build:** `swift build` → clean; `./Scripts/build_app.sh` → `dist/Remind Anything.app`

---

## 1. Summary

A native macOS menu-bar app implementing the full capture → context → compose →
schedule → remind → library loop from the design doc. 24 Swift source files, no
third-party dependencies (global hotkeys use Carbon directly instead of the
`KeyboardShortcuts` SPM lib).

---

## 2. Design → code mapping

| Design component | Implementation | Notes |
|---|---|---|
| Menu Bar App | `App/RemindAnythingApp.swift`, `UI/MenuContent.swift` | SwiftUI `MenuBarExtra`; `LSUIElement`, `.accessory` policy |
| Hotkey Manager | `Hotkeys/HotkeyManager.swift` | Carbon `RegisterEventHotKey` (self-contained) |
| Capture Engine | `Capture/CaptureEngine.swift` | `SCScreenshotManager`, region/window/full-screen |
| Region overlay | `Capture/RegionSelectionController.swift` | Borderless `NSWindow`, crosshair + live dimensions |
| Capture coordination | `Capture/CaptureCoordinator.swift`, `Capture/CaptureDraft.swift` | Orchestrates the flow |
| Context Collector | `Context/ContextCollector.swift`, `Context/BrowserContext.swift`, `Context/CaptureContext.swift` | AppleScript URL + AX window title |
| Compose UI | `UI/ComposePanelController.swift` + `UI/ComposeView.swift` | Floating non-activating `NSPanel` |
| Store | `Store/Store.swift`, `Models/Reminder.swift`, `Models/Enums.swift`, `Support/ImageStore.swift`, `Support/AppPaths.swift` | SwiftData metadata + PNGs on disk |
| Scheduler | `Scheduler/NotificationScheduler.swift` | `UNUserNotificationCenter`, calendar/interval triggers |
| Library UI | `UI/LibraryView.swift` | Search, status filters, detail, reopen/snooze/done/delete |
| Preferences | `UI/PreferencesView.swift`, `App/AppSettings.swift` | Re-bindable hotkeys, launch-at-login, permission status |
| Onboarding / permissions | `UI/OnboardingView.swift`, `Support/Permissions.swift` | First-run flow + per-permission requests |
| Login item / actions / reconcile | `App/AppDelegate.swift` | `SMAppService`, notification action handling |

---

## 3. Capture flow (as built)

1. Hotkey (⌥⇧2 region / ⌥⇧1 window / ⌥⇧3 screen) or menu triggers `CaptureCoordinator`.
2. **Context is collected first** (`ContextCollector`) while the source app is
   still frontmost — this decouples region cropping from context capture, so a
   crop of a Chrome tab still records that tab's URL.
3. Pixels grabbed silently via `SCScreenshotManager`. For region, the overlay is
   dismissed (+120 ms) before the grab so it isn't captured; the display is
   captured at backing scale and cropped to the selection.
4. Floating compose panel: thumbnail, editable context chips, note, and an
   **At / In / Every** schedule picker.
5. On save: PNG + thumbnail → `~/Library/Application Support/RemindAnything/captures/`,
   `Reminder` inserted into SwiftData, `UNNotificationRequest` scheduled.

---

## 4. Data model

`Reminder` (`@Model`) stores metadata only — id, timestamps, relative image /
thumbnail paths, context (app / window / URL / page title), note, schedule
(kind + fireDate + optional recurrence rule + snoozedUntil), and status. Enums
(`ScheduleKind`, `ReminderStatus`) are persisted as raw strings via computed
accessors for SwiftData compatibility. Binary images live on disk under
`captures/`; the SwiftData store is `RemindAnything.store`.

---

## 5. Scheduling & notifications

- `.relative` → `UNTimeIntervalNotificationTrigger`
- `.absolute` → non-repeating `UNCalendarNotificationTrigger`
- `.recurring` → repeating `UNCalendarNotificationTrigger` from a small rule
  vocabulary: `hourly`, `daily`, `weekly:<weekday>`
- Thumbnail attached to the notification.
- Actions: **Open** (reopens URL, or reveals the screenshot in Finder if no
  URL), **Snooze 10m / 1h / Tomorrow**, **Done**.
- Registers as a **login item** via `SMAppService`; reconciles pending
  reminders at launch.

---

## 6. Browser context strategy

| Browser | URL source | State |
|---|---|---|
| Chrome / Brave / Edge / Arc / Vivaldi / Chromium | AppleScript `URL of active tab of front window` | ✅ |
| Safari / Safari TP | AppleScript `URL of front document` | ✅ |
| Firefox | Accessibility fallback (window title only; no URL) | ⚠️ partial |
| Other / none | URL omitted; window title used | ✅ |

> The design specifies ScriptingBridge; v0 uses `NSAppleScript` instead — same
> underlying scripting dictionaries, but no per-app generated headers required.
> Migrating to typed ScriptingBridge is a future speed/robustness optimization.

---

## 7. Permissions

| Feature | Permission | Handling |
|---|---|---|
| Capture | Screen Recording | `CGPreflight/RequestScreenCaptureAccess`; blocks capture until granted |
| Window titles / Firefox | Accessibility | `AXIsProcessTrusted(WithOptions)` |
| Browser URL | Automation (per browser) | Prompted by macOS on first AppleScript call |
| Reminders | Notifications | `requestAuthorization` at launch + in onboarding |

Graceful degradation: if Automation/AX is denied, capture still records image +
window title, just without the URL. **No network calls** — fully local.

---

## 8. Distribution

`Scripts/build_app.sh` assembles and ad-hoc signs `Remind Anything.app`. Pass
`--sign "Developer ID Application: NAME (TEAMID)"` for a hardened-runtime signed
build ready for notarization → DMG (`create-dmg`) → Homebrew Cask.

- `App/Info.plist` — bundle id `com.mengzhang.RemindAnything`, `LSUIElement`,
  Apple Events + Accessibility usage strings.
- `App/RemindAnything.entitlements` — unsandboxed, `automation.apple-events`.

---

## 9. Deviations from the design

1. **macOS 14 minimum** (design says 13+) — SwiftData requirement.
2. **Hotkeys via Carbon** instead of `sindresorhus/KeyboardShortcuts` — removes a
   dependency; recorder implemented in `PreferencesView`.
3. **AppleScript instead of ScriptingBridge** for browser context (see §6).
4. **Region capture** = capture display + crop (not `SCStreamConfiguration.sourceRect`).

---

## 10. Known limitations / TODO (post-v0)

- Firefox address-bar **URL** extraction (currently title only).
- Recurrence is preset-based; no full RRULE editor.
- No annotation/markup on region captures.
- No auto-update (Sparkle) — relies on `brew upgrade --cask`.
- ScreenCaptureKit runtime paths are untested against a live TCC grant in CI;
  validated by compilation + local launch (menu-bar process runs).
- Multi-display coordinate conversions assume the primary screen's height as the
  top-left reference; verify on mixed-DPI multi-monitor setups.

---

## 11. Milestone status

| Phase | Deliverable | Status |
|---|---|---|
| M0 – Spike | Menu bar + hotkey + region/window grab to PNG | ✅ |
| M1 – Context | URL/title/app/window bundled into a capture | ✅ |
| M2 – Reminders | Compose panel + SwiftData + notifications | ✅ |
| M3 – Library | Browse/search/snooze/done + reopen URL | ✅ |
| M4 – Polish | Recurring, onboarding/permissions, login item | ✅ (recurrence = presets) |
| M5 – Ship | Signing, notarization, DMG, Homebrew Cask | 🚧 script ready; needs Developer ID + notarization |
