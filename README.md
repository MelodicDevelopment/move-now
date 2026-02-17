# MoveNow

A lightweight macOS menu bar app that reminds you to take movement breaks throughout the day.

MoveNow runs quietly in your menu bar and sends periodic notifications during a configurable daily time window, helping you build healthier habits at your desk.

## Features

### Menu Bar Integration

MoveNow lives in your macOS menu bar with a walking figure icon. When paused, the icon fades and displays a small pause indicator. Clicking the icon opens a dropdown panel with all app controls — no separate windows or dock icon.

### Configurable Schedule

- **Reminder interval** — Set how often you want to be reminded, from every 5 minutes up to every 4 hours (in 5-minute increments). Default is 45 minutes.
- **Daily time window** — Choose start and end times for when reminders are active. Defaults to 8:00 AM – 5:00 PM.
- **Active days** — Toggle individual days of the week on or off. All seven days are enabled by default.

### Notifications

Reminders arrive as time-sensitive macOS notifications with three response options:

- **I Moved** — Confirms you moved and resets the reminder timer
- **Log Activity** — Lets you type what you did (e.g., "walked the dog", "stretched")
- **Didn't Move** — Acknowledges the reminder and logs that you skipped it

Missed reminders repeat every 60 seconds until acknowledged, so you won't accidentally ignore one.

### Activity Logging

Every response to a reminder is logged with a timestamp and optional activity description. The menu panel shows your 5 most recent entries, and individual entries can be deleted. Activity data is stored locally as a JSON file in your Application Support directory.

An optional text field in the menu lets you log activity and reset your reminder timer at any time — you don't have to wait for a notification.

### Controls

- **Enable/Disable** — Master toggle to turn reminders on or off
- **Pause/Resume** — Temporarily pause reminders without changing your settings
- **Launch at Login** — Start MoveNow automatically when you log in (uses macOS login items)

### Status Display

The menu panel shows your current state at a glance:

- Next scheduled reminder time
- Whether reminders are paused or disabled
- Warnings if no active days are selected or the time window is invalid
- Notification permission status with a shortcut to System Settings if needed

## Privacy

MoveNow is designed with privacy as a core principle:

- **No network access** — The app never connects to the internet
- **No analytics or tracking** — Zero telemetry of any kind
- **No cloud sync** — All data stays on your Mac
- **No health, location, or motion data** — The only system permission requested is notifications
- **App Sandbox enabled** — Runs in a sandboxed environment for additional security
- **Local storage only** — Settings are stored in UserDefaults; activity logs are stored in `~/Library/Application Support/MoveNow/`

## Requirements

- macOS 13.0 (Ventura) or later

## License

All Rights Reserved. See [LICENSE](LICENSE) for details.
