import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftUI
import UserNotifications

extension Notification.Name {
    static let moveNowNotificationActivated = Notification.Name("MoveNowNotificationActivated")
    static let moveNowNotificationDismissed = Notification.Name("MoveNowNotificationDismissed")
}

private enum AppConfiguration {
    static var isRunningInAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static var showDebugRemindNow: Bool {
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "MoveNowDebugRemindNow") as? Bool {
            return plistValue
        }

        let envValue = ProcessInfo.processInfo.environment["MOVENOW_DEBUG_REMIND_NOW"]?.lowercased()
        return envValue == "1" || envValue == "true" || envValue == "yes"
    }
}

private enum AppIconAssets {
    static let menuBarSize = NSSize(width: 18, height: 18)

    static var menuBarIcon: NSImage {
        let image = loadMenuBarIconImage()
            ?? NSImage(systemSymbolName: "figure.walk.circle", accessibilityDescription: "Move Now")
            ?? NSImage()

        let copy = (image.copy() as? NSImage) ?? image
        copy.size = menuBarSize
        copy.isTemplate = true
        return copy
    }

    static var menuBarIconPaused: NSImage {
        let base = menuBarIcon
        let size = base.size

        let composited = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.45)

            // Draw two small pause bars in the top-right corner
            let barWidth: CGFloat = 1.5
            let barHeight: CGFloat = 6
            let barSpacing: CGFloat = 1.5
            let totalWidth = barWidth * 2 + barSpacing
            let originX = rect.maxX - totalWidth - 0.5
            let originY = rect.maxY - barHeight - 0.5

            NSColor.black.setFill()
            NSRect(x: originX, y: originY, width: barWidth, height: barHeight).fill()
            NSRect(x: originX + barWidth + barSpacing, y: originY, width: barWidth, height: barHeight).fill()

            return true
        }

        composited.isTemplate = true
        return composited
    }

    static var appIcon: NSImage? {
        guard let image = loadAppIconImage() else { return nil }
        let copy = (image.copy() as? NSImage) ?? image
        copy.size = NSSize(width: 512, height: 512)
        return copy
    }

    private static func loadMenuBarIconImage() -> NSImage? {
        if let mainURL = Bundle.main.url(forResource: "MoveNowStatusIcon", withExtension: "png"),
           let image = NSImage(contentsOf: mainURL) {
            return image
        }

        if let mainURL = Bundle.main.url(forResource: "MoveNowIcon", withExtension: "png"),
           let image = NSImage(contentsOf: mainURL) {
            return image
        }

        return nil
    }

    private static func loadAppIconImage() -> NSImage? {
        if let mainICNSURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: mainICNSURL) {
            return image
        }

        return loadMenuBarIconImage()
    }
}

final class NotificationCenterDelegateProxy: NSObject, UNUserNotificationCenterDelegate {
    static let reminderCategoryIdentifier = "MOVENOW_REMINDER"
    static let movedActionIdentifier = "MOVENOW_ACTION_MOVED"
    static let logActivityActionIdentifier = "MOVENOW_ACTION_LOG_ACTIVITY"
    static let didNotMoveActionIdentifier = "MOVENOW_ACTION_DID_NOT_MOVE"
    static let reminderThreadIdentifier = "move-now-reminder-thread"

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == Self.didNotMoveActionIdentifier {
            NotificationCenter.default.post(
                name: .moveNowNotificationActivated,
                object: nil,
                userInfo: ["activity": "Didn't move"]
            )
        } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier ||
            response.actionIdentifier == Self.movedActionIdentifier {
            var userInfo: [String: String] = [:]
            if let textResponse = response as? UNTextInputNotificationResponse {
                userInfo["activity"] = textResponse.userText
            }
            NotificationCenter.default.post(name: .moveNowNotificationActivated, object: nil, userInfo: userInfo)
        } else if response.actionIdentifier == UNNotificationDismissActionIdentifier {
            NotificationCenter.default.post(name: .moveNowNotificationDismissed, object: nil)
        }

        completionHandler()
    }
}

@MainActor
final class ReminderSettings: ObservableObject {
    private enum Keys {
        static let isEnabled = "isEnabled"
        static let isPaused = "isPaused"
        static let intervalMinutes = "intervalMinutes"
        static let startMinutes = "startMinutes"
        static let endMinutes = "endMinutes"
        static let activeDays = "activeDays"
    }

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published var isPaused: Bool {
        didSet { UserDefaults.standard.set(isPaused, forKey: Keys.isPaused) }
    }

    @Published var intervalMinutes: Int {
        didSet {
            let clamped = max(5, min(240, intervalMinutes))
            if intervalMinutes != clamped {
                intervalMinutes = clamped
                return
            }
            UserDefaults.standard.set(intervalMinutes, forKey: Keys.intervalMinutes)
        }
    }

    @Published var startMinutes: Int {
        didSet {
            let clamped = max(0, min(1439, startMinutes))
            if startMinutes != clamped {
                startMinutes = clamped
                return
            }
            UserDefaults.standard.set(startMinutes, forKey: Keys.startMinutes)
        }
    }

    @Published var endMinutes: Int {
        didSet {
            let clamped = max(0, min(1439, endMinutes))
            if endMinutes != clamped {
                endMinutes = clamped
                return
            }
            UserDefaults.standard.set(endMinutes, forKey: Keys.endMinutes)
        }
    }

    @Published var activeDays: Set<Int> {
        didSet { UserDefaults.standard.set(Array(activeDays), forKey: Keys.activeDays) }
    }

    init() {
        let defaults = UserDefaults.standard
        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        self.isPaused = defaults.object(forKey: Keys.isPaused) as? Bool ?? false

        let interval = defaults.object(forKey: Keys.intervalMinutes) as? Int ?? 45
        self.intervalMinutes = max(5, min(240, interval))

        let start = defaults.object(forKey: Keys.startMinutes) as? Int ?? (8 * 60)
        self.startMinutes = max(0, min(1439, start))

        let end = defaults.object(forKey: Keys.endMinutes) as? Int ?? (17 * 60)
        self.endMinutes = max(0, min(1439, end))

        let savedDays = defaults.object(forKey: Keys.activeDays) as? [Int] ?? Array(1...7)
        self.activeDays = Set(savedDays)
    }
}

struct MovementEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let activity: String

    init(activity: String = "", date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.activity = activity
    }
}

@MainActor
final class MovementLog: ObservableObject {
    @Published private(set) var entries: [MovementEntry] = []

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MoveNow", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent("movement-log.json")
        self.entries = Self.load(from: fileURL)
    }

    func addEntry(activity: String) {
        let trimmed = activity.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = MovementEntry(activity: trimmed)
        entries.insert(entry, at: 0)
        save()
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    var recentEntries: [MovementEntry] {
        Array(entries.prefix(5))
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL) -> [MovementEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([MovementEntry].self, from: data)) ?? []
    }
}

@MainActor
final class ReminderEngine: ObservableObject {
    @Published private(set) var nextReminderDate: Date?
    @Published private(set) var lastReminderDate: Date?
    @Published private(set) var lastActionMessage: String?
    @Published private(set) var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    private let settings: ReminderSettings
    private let canUseUserNotifications: Bool
    private let notificationCenterDelegate = NotificationCenterDelegateProxy()
    private var isReminderPending = false
    private var stickyReminderTimer: Timer?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    var notificationWarningText: String? {
        if !canUseUserNotifications {
            return "Running outside an app bundle. Use ./scripts/run-app.sh for Notification Center banners."
        }

        switch notificationAuthorizationStatus {
        case .denied:
            return "Notifications are off for MoveNow."
        case .notDetermined:
            return "Notification permission has not been granted yet."
        default:
            return nil
        }
    }

    var shouldShowOpenSettingsButton: Bool {
        canUseUserNotifications && notificationAuthorizationStatus == .denied
    }

    var notificationsEnabledForAlerts: Bool {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private var movementLog: MovementLog?

    func setMovementLog(_ log: MovementLog) {
        self.movementLog = log
    }

    init(settings: ReminderSettings) {
        self.settings = settings
        self.canUseUserNotifications = Bundle.main.bundleURL.pathExtension == "app"
        if !canUseUserNotifications {
            self.lastActionMessage = "Notifications unavailable in swift run mode; using sound fallback."
        } else {
            UNUserNotificationCenter.current().delegate = notificationCenterDelegate
            configureNotificationCategories()
        }
        bindSettings()
        refreshNotificationAuthorizationStatus()
        recalculateNextReminder()
        startTicker()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkForReminder()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .moveNowNotificationActivated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let activity = notification.userInfo?["activity"] as? String ?? ""
            Task { @MainActor in
                self?.movementLog?.addEntry(activity: activity)
                self?.acknowledgeAndReset()
                self?.lastActionMessage = "Reminder acknowledged from notification."
            }
        }

        NotificationCenter.default.addObserver(
            forName: .moveNowNotificationDismissed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.fireReminder(startSticky: false)
            }
        }
    }

    private func bindSettings() {
        settings.$isEnabled
            .sink { [weak self] isEnabled in
                guard let self else { return }
                if !isEnabled {
                    self.clearPendingReminder()
                }
                self.recalculateNextReminder()
            }
            .store(in: &cancellables)

        settings.$isPaused
            .sink { [weak self] isPaused in
                guard let self else { return }
                if isPaused {
                    self.clearPendingReminder()
                } else {
                    self.recalculateNextReminder()
                }
            }
            .store(in: &cancellables)

        settings.$intervalMinutes
            .sink { [weak self] _ in self?.recalculateNextReminder() }
            .store(in: &cancellables)

        settings.$startMinutes
            .sink { [weak self] _ in self?.recalculateNextReminder() }
            .store(in: &cancellables)

        settings.$endMinutes
            .sink { [weak self] _ in self?.recalculateNextReminder() }
            .store(in: &cancellables)

        settings.$activeDays
            .sink { [weak self] _ in self?.recalculateNextReminder() }
            .store(in: &cancellables)
    }

    private func startTicker() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForReminder()
            }
        }
    }

    func checkForReminder() {
        guard settings.isEnabled else {
            nextReminderDate = nil
            return
        }

        guard !settings.isPaused else { return }

        guard !isReminderPending else { return }

        if nextReminderDate == nil {
            recalculateNextReminder()
        }

        guard let nextReminderDate else { return }

        if Date() >= nextReminderDate {
            fireReminder()
            recalculateNextReminder(after: Date().addingTimeInterval(1))
        }
    }

    func acknowledgeAndReset() {
        guard settings.isEnabled else { return }
        clearPendingReminder()

        let now = Date()
        let candidate = now.addingTimeInterval(TimeInterval(settings.intervalMinutes * 60))
        nextReminderDate = adjustedToWindow(after: candidate)
    }

    func fireReminder(startSticky: Bool = true) {
        lastReminderDate = Date()

        if startSticky {
            beginPendingReminderIfNeeded()
        }

        guard canUseUserNotifications else {
            playReminderSound()
            lastActionMessage = "Reminder fired with sound fallback (not running as .app)."
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let authorizationStatus = settings.authorizationStatus

            Task { @MainActor in
                guard let self else { return }
                self.notificationAuthorizationStatus = authorizationStatus

                switch authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.scheduleNotificationRequest()
                case .notDetermined:
                    self.requestNotificationAuthorization(triggerTestReminderOnGrant: true)
                case .denied:
                    self.playReminderSound()
                    self.lastActionMessage = "Notifications are disabled for MoveNow. Enable them in System Settings."
                @unknown default:
                    self.playReminderSound()
                    self.lastActionMessage = "Notification status is unknown."
                }
            }
        }
    }

    func requestNotificationAuthorization(triggerTestReminderOnGrant: Bool = false) {
        guard canUseUserNotifications else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            Task { @MainActor in
                if let error {
                    self?.lastActionMessage = "Notification permission error: \(error.localizedDescription)"
                } else if !granted {
                    self?.lastActionMessage = "Notifications were not allowed. Enable them in System Settings."
                } else if triggerTestReminderOnGrant {
                    self?.scheduleNotificationRequest()
                }

                self?.refreshNotificationAuthorizationStatus()
            }
        }
    }

    private func scheduleNotificationRequest() {
        let content = UNMutableNotificationContent()
        content.title = "Time to move"
        content.body = "Take a quick movement break."
        content.sound = .default
        content.categoryIdentifier = NotificationCenterDelegateProxy.reminderCategoryIdentifier
        content.threadIdentifier = NotificationCenterDelegateProxy.reminderThreadIdentifier
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "move-now-reminder",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.lastActionMessage = "Failed to send reminder: \(error.localizedDescription)"
                    self?.playReminderSound()
                    return
                }

                self?.playReminderSound()
                self?.lastActionMessage = "Reminder sent at \(Self.timeFormatter.string(from: Date()))."
            }
        }
    }

    func refreshNotificationAuthorizationStatus() {
        guard canUseUserNotifications else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let authorizationStatus = settings.authorizationStatus
            Task { @MainActor in
                self?.notificationAuthorizationStatus = authorizationStatus
            }
        }
    }

    func openSystemNotificationSettings() {
        guard let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else {
            return
        }

        NSWorkspace.shared.open(settingsURL)
    }

    private func configureNotificationCategories() {
        let movedAction = UNTextInputNotificationAction(
            identifier: NotificationCenterDelegateProxy.movedActionIdentifier,
            title: "I Moved",
            options: [],
            textInputButtonTitle: "Log",
            textInputPlaceholder: "What did you do?"
        )

        let didNotMoveAction = UNNotificationAction(
            identifier: NotificationCenterDelegateProxy.didNotMoveActionIdentifier,
            title: "Didn't Move",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: NotificationCenterDelegateProxy.reminderCategoryIdentifier,
            actions: [movedAction, didNotMoveAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func beginPendingReminderIfNeeded() {
        guard !isReminderPending else { return }
        isReminderPending = true
        stickyReminderTimer?.invalidate()
        stickyReminderTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isReminderPending, self.settings.isEnabled else { return }
                self.fireReminder(startSticky: false)
            }
        }
    }

    private func clearPendingReminder() {
        isReminderPending = false
        stickyReminderTimer?.invalidate()
        stickyReminderTimer = nil

        guard canUseUserNotifications else { return }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    private func playReminderSound() {
        if let sound = NSSound(named: .init("Glass")) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func recalculateNextReminder(after referenceDate: Date = Date()) {
        guard settings.isEnabled else {
            nextReminderDate = nil
            return
        }

        nextReminderDate = nextReminder(after: referenceDate)
    }

    private func adjustedToWindow(after candidate: Date) -> Date? {
        guard settings.startMinutes < settings.endMinutes else { return nil }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: candidate)
        let dayStart = calendar.startOfDay(for: candidate)

        guard let windowStart = calendar.date(byAdding: .minute, value: settings.startMinutes, to: dayStart),
              let windowEnd = calendar.date(byAdding: .minute, value: settings.endMinutes, to: dayStart) else {
            return nil
        }

        if settings.activeDays.contains(weekday) && candidate <= windowEnd {
            if candidate >= windowStart {
                return candidate
            }

            return windowStart.addingTimeInterval(TimeInterval(settings.intervalMinutes * 60))
        }

        return nextReminder(after: candidate)
    }

    private func nextReminder(after referenceDate: Date) -> Date? {
        guard settings.startMinutes < settings.endMinutes else { return nil }

        let calendar = Calendar.current
        let intervalSeconds = TimeInterval(settings.intervalMinutes * 60)

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: referenceDate) else { continue }
            let dayStart = calendar.startOfDay(for: day)

            let weekday = calendar.component(.weekday, from: dayStart)
            guard settings.activeDays.contains(weekday) else { continue }

            guard let windowStart = calendar.date(byAdding: .minute, value: settings.startMinutes, to: dayStart),
                  let windowEnd = calendar.date(byAdding: .minute, value: settings.endMinutes, to: dayStart) else {
                continue
            }

            let firstReminder = windowStart.addingTimeInterval(intervalSeconds)
            if firstReminder > windowEnd {
                continue
            }

            if referenceDate < firstReminder {
                return firstReminder
            }

            if referenceDate >= windowEnd {
                continue
            }

            let elapsed = referenceDate.timeIntervalSince(windowStart)
            let steps = Int(elapsed / intervalSeconds) + 1
            let candidate = windowStart.addingTimeInterval(TimeInterval(steps) * intervalSeconds)

            if candidate <= windowEnd {
                return candidate
            }
        }

        return nil
    }
}

@main
struct MoveNowApp: App {
    @StateObject private var settings: ReminderSettings
    @StateObject private var engine: ReminderEngine
    @StateObject private var movementLog: MovementLog

    init() {
        let settings = ReminderSettings()
        let engine = ReminderEngine(settings: settings)
        let log = MovementLog()
        engine.setMovementLog(log)
        _settings = StateObject(wrappedValue: settings)
        _engine = StateObject(wrappedValue: engine)
        _movementLog = StateObject(wrappedValue: log)

        if let appIcon = AppIconAssets.appIcon {
            NSApplication.shared.applicationIconImage = appIcon
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(settings)
                .environmentObject(engine)
                .environmentObject(movementLog)
        } label: {
            Image(nsImage: settings.isPaused ? AppIconAssets.menuBarIconPaused : AppIconAssets.menuBarIcon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: AppIconAssets.menuBarSize.width, height: AppIconAssets.menuBarSize.height)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuContentView: View {
    @EnvironmentObject var settings: ReminderSettings
    @EnvironmentObject var engine: ReminderEngine
    @EnvironmentObject var movementLog: MovementLog
    @State private var activityText = ""

    var body: some View {
        VStack(spacing: 14) {

            // MARK: Header
            HStack {
                Text("Move Now")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $settings.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }

            // MARK: Status
            statusView
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(statusBackground, in: RoundedRectangle(cornerRadius: 6))

            // MARK: Schedule
            GroupBox {
                VStack(spacing: 8) {
                    HStack {
                        Text("Every \(settings.intervalMinutes) min")
                        Spacer()
                        Stepper("", value: $settings.intervalMinutes, in: 5...240, step: 5)
                            .labelsHidden()
                    }

                    Divider()

                    DatePicker(
                        "Start",
                        selection: Binding(
                            get: { dateFor(minutes: settings.startMinutes) },
                            set: { settings.startMinutes = minutesSinceMidnight(for: $0) }
                        ),
                        displayedComponents: [.hourAndMinute]
                    )

                    DatePicker(
                        "End",
                        selection: Binding(
                            get: { dateFor(minutes: settings.endMinutes) },
                            set: { settings.endMinutes = minutesSinceMidnight(for: $0) }
                        ),
                        displayedComponents: [.hourAndMinute]
                    )
                }
                .padding(.vertical, 2)
            } label: {
                Text("Schedule")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // MARK: Active Days
            GroupBox {
                HStack(spacing: 4) {
                    ForEach(Self.orderedDays, id: \.weekday) { day in
                        Toggle(isOn: Binding(
                            get: { settings.activeDays.contains(day.weekday) },
                            set: { isOn in
                                if isOn {
                                    settings.activeDays.insert(day.weekday)
                                } else {
                                    settings.activeDays.remove(day.weekday)
                                }
                            }
                        )) {
                            Text(day.label)
                                .font(.caption2.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .toggleStyle(.button)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 2)
            } label: {
                Text("Active Days")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // MARK: Warnings
            if settings.activeDays.isEmpty {
                warningLabel("No active days selected", color: .red)
            }

            if settings.startMinutes >= settings.endMinutes {
                warningLabel("Start must be earlier than end", color: .red)
            }

            if let notificationWarningText = engine.notificationWarningText {
                warningLabel(notificationWarningText, color: .orange)
            }

            if engine.shouldShowOpenSettingsButton {
                Button("Open Notification Settings") {
                    engine.openSystemNotificationSettings()
                }
                .buttonStyle(.link)
                .font(.caption)
            }

            if let lastActionMessage = engine.lastActionMessage {
                Text(lastActionMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // MARK: Activity Log
            TextField("What did you do? (optional)", text: $activityText)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .onSubmit {
                    guard settings.isEnabled, !settings.isPaused else { return }
                    logAndAcknowledge()
                }

            // MARK: Actions
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        logAndAcknowledge()
                    } label: {
                        Text("I Moved")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!settings.isEnabled || settings.isPaused)

                    Button {
                        settings.isPaused.toggle()
                    } label: {
                        Text(settings.isPaused ? "Resume" : "Pause")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!settings.isEnabled)
                }
                .controlSize(.large)

                if AppConfiguration.showDebugRemindNow {
                    Button("Remind Now") {
                        engine.fireReminder(startSticky: false)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!settings.isEnabled)
                }
            }

            // MARK: Recent Activity
            if !movementLog.recentEntries.isEmpty {
                DisclosureGroup("Recent Activity") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(movementLog.recentEntries) { entry in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(Self.entryTimeFormatter.string(from: entry.date))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Text(entry.activity.isEmpty ? "Moved" : entry.activity)
                                Spacer()
                                Button {
                                    movementLog.deleteEntry(id: entry.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .font(.caption)
            }

            // MARK: Footer
            Divider()

            if AppConfiguration.isRunningInAppBundle {
                Toggle("Launch at Login", isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            // Registration failed — toggle will revert on next read
                        }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.caption)
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            engine.refreshNotificationAuthorizationStatus()
        }
    }

    // MARK: - Actions

    private func logAndAcknowledge() {
        movementLog.addEntry(activity: activityText)
        activityText = ""
        engine.acknowledgeAndReset()
    }

    // MARK: - Day data

    private static let entryTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private static let orderedDays: [(weekday: Int, label: String)] = [
        (1, "Su"), (2, "Mo"), (3, "Tu"), (4, "We"), (5, "Th"), (6, "Fr"), (7, "Sa"),
    ]

    // MARK: - Status helpers

    @ViewBuilder
    private var statusView: some View {
        if settings.isPaused {
            Label("Paused", systemImage: "pause.circle.fill")
                .foregroundStyle(.orange)
        } else if !settings.isEnabled {
            Label("Disabled", systemImage: "moon.fill")
                .foregroundStyle(.secondary)
        } else if let next = engine.nextReminderDate {
            Label(nextReminderText(for: next), systemImage: "clock")
                .foregroundStyle(.primary)
        } else {
            Label("No upcoming reminder", systemImage: "clock")
                .foregroundStyle(.secondary)
        }
    }

    private var statusBackground: some ShapeStyle {
        if settings.isPaused {
            return AnyShapeStyle(.orange.opacity(0.1))
        } else {
            return AnyShapeStyle(.quaternary)
        }
    }

    private func nextReminderText(for date: Date) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        if Calendar.current.isDateInToday(date) {
            return "Next: \(timeFormatter.string(from: date))"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            return "Next: \(dateFormatter.string(from: date))"
        }
    }

    private func warningLabel(_ text: String, color: Color) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Date helpers

    private func dateFor(minutes: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: minutes, to: today) ?? Date()
    }

    private func minutesSinceMidnight(for date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return (hour * 60) + minute
    }
}
