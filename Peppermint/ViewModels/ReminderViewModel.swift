//
//  ReminderViewModel.swift
//  Peppermint
//
//  Created by Claude on 2026-03-12.
//

import Foundation
import Combine
import UserNotifications
import UIKit

/// ViewModel managing reminder schedules for medications with UserNotifications authorization
@MainActor
class ReminderViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Array of reminder schedules for the current medication
    @Published var schedules: [ReminderSchedule] = []

    /// Authorization status for UserNotifications
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Error message to display to user
    @Published var errorMessage: String?

    /// Loading state for async operations
    @Published var isLoading: Bool = false

    // MARK: - Dependencies

    private let notificationService: NotificationService
    private let persistenceService: DataPersistenceService

    // MARK: - Initialization

    init(
        notificationService: NotificationService = NotificationService.shared,
        persistenceService: DataPersistenceService = DataPersistenceService.shared
    ) {
        self.notificationService = notificationService
        self.persistenceService = persistenceService

        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization Helpers

    /// Check current notification authorization status
    func checkAuthorizationStatus() async {
        let status = await notificationService.getAuthorizationStatus()
        authorizationStatus = status
    }

    /// Request notification permissions from user
    func requestAuthorization() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let granted = try await notificationService.requestAuthorization()
            await checkAuthorizationStatus()

            if !granted {
                errorMessage = "Notification permissions are required to set medication reminders. Please enable them in Settings."
            }

            return granted
        } catch {
            errorMessage = "Failed to request notification permissions: \(error.localizedDescription)"
            return false
        }
    }

    /// Open system settings for notification permissions
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Schedule Management

    /// Load reminder schedules for a specific medication
    func loadSchedules(for medication: Medication) {
        if let reminderSchedules = medication.reminderSchedules as? Set<ReminderSchedule> {
            schedules = Array(reminderSchedules).sorted { $0.createdAt ?? Date() < $1.createdAt ?? Date() }
        } else {
            schedules = []
        }
    }

    /// Create a new reminder schedule
    func createSchedule(
        for medication: Medication,
        frequency: String,
        timesOfDay: [String],
        daysOfWeek: [Int]?,
        customDates: [Date]?,
        soundName: String? = nil
    ) async -> Bool {
        // Check authorization first
        if authorizationStatus == .notDetermined {
            let granted = await requestAuthorization()
            if !granted { return false }
        } else if authorizationStatus == .denied {
            errorMessage = "Notification permissions denied. Please enable them in Settings."
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Create ReminderSchedule entity
            let schedule = ReminderSchedule(context: persistenceService.viewContext)
            schedule.id = UUID()
            schedule.enabled = true
            schedule.frequency = frequency
            schedule.soundName = soundName
            schedule.createdAt = Date()
            schedule.modifiedAt = Date()
            schedule.medication = medication

            // Encode times of day as JSON
            let timesData = try JSONEncoder().encode(timesOfDay)
            schedule.timesOfDay = timesData

            // Encode days of week as JSON if weekly
            if let daysOfWeek = daysOfWeek {
                let daysData = try JSONEncoder().encode(daysOfWeek)
                schedule.daysOfWeek = daysData
            }

            // Encode custom dates as JSON if custom
            if let customDates = customDates {
                let dateStrings = customDates.map { ISO8601DateFormatter().string(from: $0) }
                let datesData = try JSONEncoder().encode(dateStrings)
                schedule.customDates = datesData
            }

            // Save to CoreData
            try persistenceService.viewContext.save()

            // Schedule notifications
            try await notificationService.scheduleNotifications(for: schedule)

            // Reload schedules
            loadSchedules(for: medication)

            return true
        } catch {
            errorMessage = "Failed to create reminder: \(error.localizedDescription)"
            return false
        }
    }

    /// Update an existing reminder schedule
    func updateSchedule(_ schedule: ReminderSchedule) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            schedule.modifiedAt = Date()
            try persistenceService.viewContext.save()

            // Cancel old notifications
            await notificationService.cancelNotifications(for: schedule)

            // Schedule new notifications if enabled
            if schedule.enabled {
                try await notificationService.scheduleNotifications(for: schedule)
            }

            return true
        } catch {
            errorMessage = "Failed to update reminder: \(error.localizedDescription)"
            return false
        }
    }

    /// Delete a reminder schedule
    func deleteSchedule(_ schedule: ReminderSchedule) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            // Cancel notifications first
            await notificationService.cancelNotifications(for: schedule)

            // Get medication before deleting schedule
            guard let medication = schedule.medication else {
                errorMessage = "Schedule has no associated medication"
                return false
            }

            // Delete from CoreData
            persistenceService.viewContext.delete(schedule)
            try persistenceService.viewContext.save()

            // Reload schedules
            loadSchedules(for: medication)

            return true
        } catch {
            errorMessage = "Failed to delete reminder: \(error.localizedDescription)"
            return false
        }
    }

    /// Toggle schedule enabled state
    func toggleSchedule(_ schedule: ReminderSchedule) async -> Bool {
        schedule.enabled.toggle()
        return await updateSchedule(schedule)
    }
}
