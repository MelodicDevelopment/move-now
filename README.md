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

## Run

```bash
swift run
```

`swift run` works for menu bar behavior, but runs as a plain executable (not an app bundle). In that mode, reminders use a sound fallback (`beep`) instead of Notification Center banners.

For full Notification Center reminders, launch via the local app bundle script:

```bash
./scripts/run-app.sh
```

If `MoveNow` does not appear in macOS Notification settings:

```bash
./scripts/reset-notification-permission.sh
./scripts/run-app.sh
```

Then click `Remind Now` once to force a notification request.

## Notes

- On first bundled run, macOS will ask for notification permission.
- Time window currently assumes `start < end` on the same day (no overnight windows).
- First reminder in a window is `start + interval`.
