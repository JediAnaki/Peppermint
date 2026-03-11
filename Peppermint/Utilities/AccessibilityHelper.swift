import Foundation
import UIKit

struct AccessibilityHelper {
    /// Generates a VoiceOver label for a compartment
    /// - Parameters:
    ///   - compartment: The compartment entity
    /// - Returns: Accessibility label string
    static func compartmentLabel(for compartment: Compartment) -> String {
        let position = "Position: \(Int(compartment.positionX))mm, \(Int(compartment.positionY))mm, \(Int(compartment.positionZ))mm"
        let dimensions = "Size: \(Int(compartment.width))×\(Int(compartment.height))×\(Int(compartment.depth))mm"

        var label = "Compartment. \(dimensions). \(position)"

        if let medication = compartment.medication {
            label += ". Contains \(medication.name ?? "unnamed medication")"

            if medication.isExpired {
                label += ". Expired"
            } else if medication.isExpiringSoon {
                label += ". Expiring soon"
            }
        } else {
            label += ". Empty"
        }

        return label
    }

    /// Generates a VoiceOver label for a medication
    /// - Parameters:
    ///   - medication: The medication entity
    /// - Returns: Accessibility label string
    static func medicationLabel(for medication: Medication) -> String {
        var label = medication.name ?? "Unnamed medication"

        if let category = medication.category {
            label += ". Category: \(category)"
        }

        if let expirationDate = medication.expirationDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none

            label += ". Expires: \(dateFormatter.string(from: expirationDate))"

            if medication.isExpired {
                label += ". This medication has expired"
            } else if medication.isExpiringSoon {
                let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
                label += ". Expiring in \(days) days"
            }
        }

        if medication.hasActiveReminders {
            label += ". Reminders enabled"
        }

        return label
    }

    /// Generates a VoiceOver label for a reminder schedule
    /// - Parameters:
    ///   - schedule: The reminder schedule entity
    /// - Returns: Accessibility label string
    static func reminderLabel(for schedule: ReminderSchedule) -> String {
        guard schedule.enabled else {
            return "Reminder disabled"
        }

        var label = "Reminder"

        if let frequency = schedule.frequency {
            switch frequency {
            case "daily":
                label += ". Daily"
            case "weekly":
                label += ". Weekly"
            case "custom":
                label += ". Custom schedule"
            default:
                break
            }
        }

        if let timesData = schedule.timesOfDay,
           let times = try? JSONDecoder().decode([String].self, from: timesData),
           let firstTime = times.first {
            label += ". At \(firstTime)"
            if times.count > 1 {
                label += " and \(times.count - 1) more time\(times.count > 2 ? "s" : "")"
            }
        }

        if let nextTime = schedule.nextOccurrence {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relativeTime = formatter.localizedString(for: nextTime, relativeTo: Date())
            label += ". Next reminder \(relativeTime)"
        }

        return label
    }

    /// Generates a VoiceOver label for an organizer design
    /// - Parameters:
    ///   - organizer: The organizer design entity
    /// - Returns: Accessibility label string
    static func organizerLabel(for organizer: OrganizerDesign) -> String {
        var label = organizer.name ?? "Unnamed organizer"

        let compartmentCount = organizer.compartmentCount
        label += ". \(compartmentCount) compartment\(compartmentCount != 1 ? "s" : "")"

        if organizer.hasActiveMedications {
            label += ". Contains medications"
        }

        if organizer.hasPendingReminders {
            label += ". Has active reminders"
        }

        if let modifiedDate = organizer.modifiedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let relativeTime = formatter.localizedString(for: modifiedDate, relativeTo: Date())
            label += ". Last modified \(relativeTime)"
        }

        return label
    }

    /// Returns accessibility traits for a given view type
    /// - Parameters:
    ///   - viewType: The type of view element
    /// - Returns: Accessibility traits
    static func traits(for viewType: ViewType) -> UIAccessibilityTraits {
        switch viewType {
        case .button:
            return .button
        case .header:
            return .header
        case .staticText:
            return .staticText
        case .adjustable:
            return .adjustable
        case .searchField:
            return .searchField
        case .selected:
            return .selected
        default:
            return .none
        }
    }

    enum ViewType {
        case button
        case header
        case staticText
        case adjustable
        case searchField
        case selected
        case none
    }

    /// Checks if Dynamic Type is enabled with a larger text size
    static var isDynamicTypeEnabled: Bool {
        let category = UIApplication.shared.preferredContentSizeCategory
        return category >= .accessibilityMedium
    }

    /// Checks if Reduce Motion is enabled
    static var isReduceMotionEnabled: Bool {
        return UIAccessibility.isReduceMotionEnabled
    }

    /// Checks if VoiceOver is running
    static var isVoiceOverRunning: Bool {
        return UIAccessibility.isVoiceOverRunning
    }
}
