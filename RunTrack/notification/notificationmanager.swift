import Foundation
import Combine
import UserNotifications

/// Gère l'autorisation et la planification des notifications locales (rappel hebdomadaire).
@MainActor
final class NotificationManager: ObservableObject {
    @Published var isAuthorized = false

    @Published var isWeeklyReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isWeeklyReminderEnabled, forKey: Keys.enabled)
            Task { await applyReminderState() }
        }
    }

    /// 1 = dimanche, 2 = lundi, ... 7 = samedi (convention Calendar/DateComponents).
    @Published var reminderWeekday: Int {
        didSet {
            UserDefaults.standard.set(reminderWeekday, forKey: Keys.weekday)
            Task { await applyReminderState() }
        }
    }

    @Published var reminderHour: Int {
        didSet {
            UserDefaults.standard.set(reminderHour, forKey: Keys.hour)
            Task { await applyReminderState() }
        }
    }

    @Published var reminderMinute: Int {
        didSet {
            UserDefaults.standard.set(reminderMinute, forKey: Keys.minute)
            Task { await applyReminderState() }
        }
    }

    private enum Keys {
        static let enabled = "weeklyReminderEnabled"
        static let weekday = "weeklyReminderWeekday"
        static let hour = "weeklyReminderHour"
        static let minute = "weeklyReminderMinute"
    }

    private static let reminderIdentifier = "weeklyRunReminder"

    init() {
        let defaults = UserDefaults.standard
        self.isWeeklyReminderEnabled = defaults.bool(forKey: Keys.enabled)
        self.reminderWeekday = defaults.object(forKey: Keys.weekday) as? Int ?? 1 // dimanche par défaut
        self.reminderHour = defaults.object(forKey: Keys.hour) as? Int ?? 18
        self.reminderMinute = defaults.object(forKey: Keys.minute) as? Int ?? 0
    }

    /// Demande l'autorisation si elle n'a jamais été demandée, et met à jour `isAuthorized`.
    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                isAuthorized = granted
            } catch {
                isAuthorized = false
            }
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        default:
            isAuthorized = false
        }

        await applyReminderState()
    }

    private func applyReminderState() async {
        guard isAuthorized else { return }
        if isWeeklyReminderEnabled {
            await scheduleWeeklyReminder()
        } else {
            cancelWeeklyReminder()
        }
    }

    private func scheduleWeeklyReminder() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "C'est l'heure de courir 🏃"
        content.body = "Pense à prévoir ta sortie de la semaine pour garder ta dynamique."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = reminderWeekday
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.reminderIdentifier, content: content, trigger: trigger)

        try? await center.add(request)
    }

    private func cancelWeeklyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])
    }
}
