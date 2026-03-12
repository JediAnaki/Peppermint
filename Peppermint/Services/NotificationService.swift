//
//  NotificationService.swift
//  Peppermint
//
//  Created by Claude on 2026-03-12.
//

import Foundation
import UserNotifications

/// Service wrapping UserNotifications framework for medication reminder scheduling
class NotificationService: NSObject {
    // MARK: - Singleton

    static let shared = NotificationService()

    // MARK: - Properties

    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Initialization

    private override init() {
        super.init()
        notificationCenter.delegate = self
    }

    // MARK: - Authorization

    /// Request notification authorization from user
    func requestAuthorization() async throws -> Bool {
        return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Get current authorization status
    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Schedule Management

    /// Schedule notifications for a reminder schedule
    func scheduleNotifications(for schedule: ReminderSchedule) async throws {
        guard schedule.enabled else { return }
        guard let medication = schedule.medication else {
            throw NotificationError.missingMedication
        }

        // Decode times of day
        guard let timesData = schedule.timesOfDay,
              let timesOfDay = try? JSONDecoder().decode([String].self, from: timesData) else {
            throw NotificationError.invalidTimesOfDay
        }

        // Cancel existing notifications for this schedule
        await cancelNotifications(for: schedule)

        // Schedule based on frequency
        switch schedule.frequency {
        case "daily":
            try await scheduleDailyNotifications(
                for: medication,
                scheduleId: schedule.id?.uuidString ?? UUID().uuidString,
                timesOfDay: timesOfDay,
                soundName: schedule.soundName
            )

        case "weekly":
            guard let daysData = schedule.daysOfWeek,
                  let daysOfWeek = try? JSONDecoder().decode([Int].self, from: daysData) else {
                throw NotificationError.invalidDaysOfWeek
            }

            try await scheduleWeeklyNotifications(
                for: medication,
                scheduleId: schedule.id?.uuidString ?? UUID().uuidString,
                timesOfDay: timesOfDay,
                daysOfWeek: daysOfWeek,
                soundName: schedule.soundName
            )

        case "custom":
            guard let datesData = schedule.customDates,
                  let dateStrings = try? JSONDecoder().decode([String].self, from: datesData) else {
                throw NotificationError.invalidCustomDates
            }

            let dates = dateStrings.compactMap { ISO8601DateFormatter().date(from: $0) }
            try await scheduleCustomNotifications(
                for: medication,
                scheduleId: schedule.id?.uuidString ?? UUID().uuidString,
                timesOfDay: timesOfDay,
                customDates: dates,
                soundName: schedule.soundName
            )

        default:
            throw NotificationError.unsupportedFrequency
        }
    }

    /// Cancel notifications for a reminder schedule
    func cancelNotifications(for schedule: ReminderSchedule) async {
        guard let scheduleId = schedule.id?.uuidString else { return }

        // Get all pending notifications
        let pendingRequests = await notificationCenter.pendingNotificationRequests()

        // Filter notifications belonging to this schedule
        let identifiersToRemove = pendingRequests
            .filter { $0.identifier.hasPrefix("\(scheduleId)-") }
            .map { $0.identifier }

        // Cancel them
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
    }

    // MARK: - Private Scheduling Methods

    private func scheduleDailyNotifications(
        for medication: Medication,
        scheduleId: String,
        timesOfDay: [String],
        soundName: String?
    ) async throws {
        for (index, timeString) in timesOfDay.enumerated() {
            let components = parseTime(timeString)

            let content = createNotificationContent(
                for: medication,
                soundName: soundName
            )

            // Create daily trigger
            var dateComponents = DateComponents()
            dateComponents.hour = components.hour
            dateComponents.minute = components.minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let identifier = "\(scheduleId)-daily-\(index)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            try await notificationCenter.add(request)
        }
    }

    private func scheduleWeeklyNotifications(
        for medication: Medication,
        scheduleId: String,
        timesOfDay: [String],
        daysOfWeek: [Int],
        soundName: String?
    ) async throws {
        for (timeIndex, timeString) in timesOfDay.enumerated() {
            let timeComponents = parseTime(timeString)

            for dayOfWeek in daysOfWeek {
                let content = createNotificationContent(
                    for: medication,
                    soundName: soundName
                )

                // Create weekly trigger
                var dateComponents = DateComponents()
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                dateComponents.weekday = dayOfWeek + 1 // iOS weekday: 1=Sunday, 2=Monday, etc.

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: true
                )

                let identifier = "\(scheduleId)-weekly-\(timeIndex)-\(dayOfWeek)"
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )

                try await notificationCenter.add(request)
            }
        }
    }

    private func scheduleCustomNotifications(
        for medication: Medication,
        scheduleId: String,
        timesOfDay: [String],
        customDates: [Date],
        soundName: String?
    ) async throws {
        let calendar = Calendar.current

        for (dateIndex, date) in customDates.enumerated() {
            for (timeIndex, timeString) in timesOfDay.enumerated() {
                let timeComponents = parseTime(timeString)

                // Combine date and time
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute

                let content = createNotificationContent(
                    for: medication,
                    soundName: soundName
                )

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: false
                )

                let identifier = "\(scheduleId)-custom-\(dateIndex)-\(timeIndex)"
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )

                try await notificationCenter.add(request)
            }
        }
    }

    // MARK: - Helper Methods

    private func createNotificationContent(
        for medication: Medication,
        soundName: String?
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = medication.name ?? "Medication Reminder"

        // Include compartment location if available
        if let compartment = medication.compartment {
            let position = "Position: (\(Int(compartment.positionX))mm, \(Int(compartment.positionY))mm, \(Int(compartment.positionZ))mm)"
            content.body = "Time to take your medication. \(position)"
        } else {
            content.body = "Time to take your medication."
        }

        // Set sound
        if let soundName = soundName {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        } else {
            content.sound = .default
        }

        // Add badge
        content.badge = 1

        // Add user info for navigation
        if let medicationId = medication.id?.uuidString,
           let compartmentId = medication.compartment?.id?.uuidString {
            content.userInfo = [
                "medicationId": medicationId,
                "compartmentId": compartmentId
            ]
        }

        return content
    }

    private func parseTime(_ timeString: String) -> (hour: Int, minute: Int) {
        let components = timeString.split(separator: ":")
        let hour = Int(components[0]) ?? 0
        let minute = Int(components[1]) ?? 0
        return (hour: hour, minute: minute)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Post notification for app to handle navigation
        let userInfo = response.notification.request.content.userInfo
        NotificationCenter.default.post(
            name: .didReceiveMedicationReminder,
            object: nil,
            userInfo: userInfo
        )

        completionHandler()
    }
}

// MARK: - Errors

enum NotificationError: LocalizedError {
    case missingMedication
    case invalidTimesOfDay
    case invalidDaysOfWeek
    case invalidCustomDates
    case unsupportedFrequency

    var errorDescription: String? {
        switch self {
        case .missingMedication:
            return "Reminder schedule has no associated medication"
        case .invalidTimesOfDay:
            return "Invalid times of day format"
        case .invalidDaysOfWeek:
            return "Invalid days of week format"
        case .invalidCustomDates:
            return "Invalid custom dates format"
        case .unsupportedFrequency:
            return "Unsupported reminder frequency"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didReceiveMedicationReminder = Notification.Name("didReceiveMedicationReminder")
}
