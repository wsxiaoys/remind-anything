# Remind Anything — v0 Feedback

This document curates feedback and suggested improvements against the v0 implementation status ([`status.md`](status.md)).

---

## 1. Multi-Screen / Multi-Monitor Support

### Issue: Region selector only presents on primary display
- **Description:** Currently, in a multi-screen setup, the region selector overlay only appears on the primary display. It does not appear on the display that currently has focus (e.g., where the mouse cursor is located).
- **Impact:** Users working across multiple monitors cannot easily select or capture regions on secondary displays.
- **Potential Solution:**
  - Detect the active screen containing the mouse cursor (e.g., using `NSScreen.main` or finding the screen matching `NSEvent.mouseLocation`).
  - Position and present the `RegionSelectionController` / overlay window on that specific screen instead of defaulting to the primary screen.

## 2. Window Management / Focus

### Issue: Preferences window does not pop to front
- **Description:** When clicking `Preferences` from the menu bar app, the Preferences window opens but does not pop to the front; it remains behind the currently focused window (e.g., VS Code).
- **Impact:** Poor user experience, as the user might think the click didn't work, and they have to manually find/bring the window to the foreground.
- **Potential Solution:**
  - Ensure that when the Preferences window is ordered to front, the application is also activated.
  - For example, call `NSApp.activate(ignoringOtherApps: true)` before showing the Preferences window, or call `window.makeKeyAndOrderFront(nil)` along with application activation.

## 3. Onboarding & Menu Bar UX

### Issue: Unable to open the welcome/onboarding page from the menu bar
- **Description:** There is currently no way to reopen the welcome/onboarding page from the menu bar once it has been closed or completed. 
- **Impact:** Users might want to revisit the onboarding steps, re-read the quick start guide, or re-verify permissions easily.
- **Potential Solution:**
  - Add a menu item like `Welcome to Remind Anything...` or `Show Welcome Screen` to the menu bar extra dropdown.
  - Alternatively, integrate or link the welcome/onboarding view directly within the Preferences window (e.g., as a tab or a button to "Rerun Onboarding").

## 4. Compose UI & Schedule Picker

### Issue: Reminder interval selection is too granular / lacks standard presets (Slack-style)
- **Description:** The current reminder interval picker is very granular (e.g., increments of minutes, like "55 min") and lacks convenient, standard presets.

  ![Current granular interval picker](assets/interval_picker.png)

- **Impact:** It is tedious for users to set reminders for common timeframes compared to other productivity apps like Slack.
- **Potential Solution:**
  - Introduce Slack-style presets for the schedule picker (e.g., "In 1 hour", "In 3 hours", "Tomorrow", "Next week", "In 3 days").
  - Provide a list of common presets while still allowing custom intervals if needed.
