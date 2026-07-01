# Remind Anything — Iteration 1 Feedback

This document curates feedback and suggested improvements gathered while testing
the current build (post iteration-0, see [`../iteration-0/feedback.md`](../iteration-0/feedback.md)).

Each item is addressed independently and committed (or cleanly reverted) on its
own, per the dev-iteration loop.

---

## 1. Hide onboarding menu item once permissions are set up

### Issue: "Welcome to Remind Anything…" always shows in the menu
- **Description:** The menu-bar dropdown always shows the `Welcome to Remind
  Anything…` item. Once all required permissions are properly granted, the
  onboarding entry point is redundant clutter.
- **Impact:** Unnecessary menu item for users who are fully set up.
- **Potential Solution:** Only show `Welcome to Remind Anything…` while at least
  one required permission (Screen Recording, Accessibility, Notifications) is not
  yet granted; hide it once all are granted.
- **Impacted files:** `UI/MenuContent.swift`, `Support/Permissions.swift`.

## 2. Make the note field optional when creating a reminder

### Issue: A note is required to create a reminder
- **Description:** When composing a reminder, the `note` field appears to be
  required. It should be optional — Slack-style "just remind me about this
  thing" where you can save a reminder without typing anything.
- **Impact:** Extra friction for the common case of quickly capturing something
  to revisit without needing a written note.
- **Potential Solution:** Allow saving a reminder with an empty note; keep the
  note purely optional.

## 3. General Preferences UX updates

### Issue: Unnecessary default reminder setting & Launch at Login disabled by default
- **Description:** The General Preferences tab has two issues:
  1. It includes a "Default reminder: in 60 min" stepper, which is redundant now that we use Slack-style presets.
  2. "Launch at login" is disabled by default.
- **Impact:** Redundant settings clutter the UI, and users miss reminders if they forget to manually enable "Launch at login".
- **Potential Solution:**
  1. Remove the "Default reminder" setting entirely.
  2. Make "Launch at login" enabled by default on first launch.
- **Visual Reference:**
  ![General Preferences](assets/preferences.png)

## 4. Redesign Preferences window in "Handy" style

### Issue: Standard macOS preferences window feels generic
- **Description:** The current Preferences window uses standard macOS tab bars. The user prefers the "Handy" app settings style:
  - Left sidebar with vertical tabs (General, Shortcuts/Hotkeys, Permissions).
  - Main settings content area on the right with clear, grouped card-style sections.
  - Individual setting rows with titles, optional descriptions, and right-aligned controls (toggles, pickers).
- **Impact:** Improving the visual design, polish, and layout of the Preferences window.
- **Potential Solution:** Redesign `PreferencesView` to use a sidebar navigation layout on the left and grouped section cards on the right.
- **Visual Reference:**
  ![Handy Style Preferences](assets/handy_style.png)
