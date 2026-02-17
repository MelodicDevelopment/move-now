# MoveNow MVP

Menu bar macOS app that sends reminder notifications every N minutes within a daily time window.

## What this MVP does

- Runs from the menu bar (`figure.walk.circle` icon)
- Lets you configure:
  - Reminder interval (5-240 minutes)
  - Start time
  - End time
- Only sends reminders during the configured time window
- Supports:
  - Enable/disable reminders
  - `I Moved` (resets next reminder based on interval)
  - `Remind Now` (manual test notification)
- Persists settings in `UserDefaults`

## Build & Run

Open `MoveNow.xcodeproj` in Xcode and run the MoveNow scheme (Cmd+R).

The project can also be built from the command line:

```bash
xcodebuild -project MoveNow.xcodeproj -scheme MoveNow -configuration Debug build
```

## Notes

- On first run, macOS will ask for notification permission.
- Time window currently assumes `start < end` on the same day (no overnight windows).
- First reminder in a window is `start + interval`.
