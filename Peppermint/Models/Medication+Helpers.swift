//
//  Medication+Helpers.swift
//  Peppermint
//
//  Created for Feature: OpenSCAD-Based STL Export with Cloud Sync
//  Helper computed properties for Medication entity
//

import Foundation
import UIKit

// MARK: - Medication Computed Properties

extension Medication {

    /// Checks if the medication has expired
    ///
    /// - Returns: `true` if the expiration date has passed, `false` otherwise
    var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return expirationDate < Date()
    }

    /// Checks if the medication is expiring soon (within 30 days)
    ///
    /// - Returns: `true` if the expiration date is within 30 days, `false` otherwise
    var isExpiringSoon: Bool {
        guard let expirationDate = expirationDate else { return false }

        // Don't mark as expiring soon if already expired
        if isExpired { return false }

        // Check if expiring within 30 days
        let thirtyDaysFromNow = Date().addingTimeInterval(30 * 24 * 60 * 60)
        return expirationDate <= thirtyDaysFromNow
    }

    /// Checks if the medication has any active (enabled) reminder schedules
    ///
    /// - Returns: `true` if at least one reminder schedule is enabled, `false` otherwise
    var hasActiveReminders: Bool {
        guard let schedules = reminderSchedules as? Set<ReminderSchedule> else { return false }
        return schedules.contains { $0.enabled }
    }

    /// Returns a warning color based on medication expiration status
    ///
    /// **Color mapping**:
    /// - Red: Medication has expired
    /// - Orange: Medication is expiring soon (within 30 days)
    /// - Green: Medication is valid (no expiration date or far from expiration)
    ///
    /// - Returns: UIColor for visual warning indication
    var warningColor: UIColor {
        if isExpired {
            return UIColor.systemRed  // Expired - critical warning
        } else if isExpiringSoon {
            return UIColor.systemOrange  // Expiring soon - caution
        } else {
            return UIColor.systemGreen  // Valid - all good
        }
    }
}
