import Foundation
import CoreData
import UIKit

@objc(Medication)
public class Medication: NSManagedObject {
    // Computed properties
    var isExpiringSoon: Bool {
        guard let expirationDate = expirationDate else { return false }
        let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return daysUntilExpiration <= 30 && daysUntilExpiration >= 0
    }

    var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return expirationDate < Date()
    }

    var warningColor: UIColor {
        guard let expirationDate = expirationDate else { return .clear }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0

        if days < 0 { return .systemRed }      // Expired
        if days < 7 { return .systemOrange }   // <7 days
        if days < 30 { return .systemYellow }  // <30 days
        return .clear
    }

    var hasActiveReminders: Bool {
        guard let schedules = reminderSchedules as? Set<ReminderSchedule> else { return false }
        return schedules.contains { $0.enabled }
    }

    var nextReminderTime: Date? {
        guard let schedules = reminderSchedules as? Set<ReminderSchedule> else { return nil }
        let enabledSchedules = schedules.filter { $0.enabled }

        var nextTimes: [Date] = []
        for schedule in enabledSchedules {
            if let nextTime = schedule.nextOccurrence {
                nextTimes.append(nextTime)
            }
        }

        return nextTimes.min()
    }
}
