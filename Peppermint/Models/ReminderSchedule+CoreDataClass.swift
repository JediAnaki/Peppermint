import Foundation
import CoreData

@objc(ReminderSchedule)
public class ReminderSchedule: NSManagedObject {
    enum ReminderFrequency: String {
        case daily = "daily"
        case weekly = "weekly"
        case custom = "custom"
    }

    // Computed properties
    var nextOccurrence: Date? {
        guard enabled else { return nil }
        guard let frequencyString = frequency,
              let reminderFrequency = ReminderFrequency(rawValue: frequencyString) else {
            return nil
        }

        let calendar = Calendar.current
        let now = Date()

        // Decode times of day from JSON
        guard let timesData = timesOfDay,
              let times = try? JSONDecoder().decode([String].self, from: timesData) else {
            return nil
        }

        switch reminderFrequency {
        case .daily:
            // Find next occurrence of any time today or tomorrow
            var upcomingTimes: [Date] = []
            for timeString in times {
                if let nextTime = nextOccurrence(for: timeString, from: now, calendar: calendar) {
                    upcomingTimes.append(nextTime)
                }
            }
            return upcomingTimes.min()

        case .weekly:
            // Decode days of week
            guard let daysData = daysOfWeek,
                  let days = try? JSONDecoder().decode([Int].self, from: daysData) else {
                return nil
            }

            var upcomingTimes: [Date] = []
            for day in days {
                for timeString in times {
                    if let nextTime = nextWeeklyOccurrence(for: timeString, on: day, from: now, calendar: calendar) {
                        upcomingTimes.append(nextTime)
                    }
                }
            }
            return upcomingTimes.min()

        case .custom:
            // Decode custom dates
            guard let customDatesData = customDates,
                  let dates = try? JSONDecoder().decode([String].self, from: customDatesData) else {
                return nil
            }

            let dateFormatter = ISO8601DateFormatter()
            var futureDates: [Date] = []
            for dateString in dates {
                if let date = dateFormatter.date(from: dateString), date > now {
                    futureDates.append(date)
                }
            }
            return futureDates.min()
        }
    }

    var isOverdue: Bool {
        guard enabled, let next = nextOccurrence else { return false }
        return next < Date()
    }

    // Helper methods
    private func nextOccurrence(for timeString: String, from date: Date, calendar: Calendar) -> Date? {
        let components = timeString.split(separator: ":").map { Int($0) }
        guard components.count == 2,
              let hour = components[0],
              let minute = components[1] else {
            return nil
        }

        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        guard let scheduledTime = calendar.date(from: dateComponents) else { return nil }

        // If time has passed today, return tomorrow's occurrence
        if scheduledTime <= date {
            return calendar.date(byAdding: .day, value: 1, to: scheduledTime)
        }

        return scheduledTime
    }

    private func nextWeeklyOccurrence(for timeString: String, on weekday: Int, from date: Date, calendar: Calendar) -> Date? {
        let components = timeString.split(separator: ":").map { Int($0) }
        guard components.count == 2,
              let hour = components[0],
              let minute = components[1] else {
            return nil
        }

        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        // Find next occurrence of this weekday
        guard let nextDate = calendar.nextDate(after: date, matching: dateComponents, matchingPolicy: .nextTime) else {
            return nil
        }

        return nextDate
    }
}
