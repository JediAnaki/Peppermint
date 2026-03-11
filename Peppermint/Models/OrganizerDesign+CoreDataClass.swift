import Foundation
import CoreData

@objc(OrganizerDesign)
public class OrganizerDesign: NSManagedObject {
    // Computed properties
    var compartmentCount: Int {
        return compartments?.count ?? 0
    }

    var hasActiveMedications: Bool {
        guard let compartments = compartments as? Set<Compartment> else { return false }
        return compartments.contains { $0.medication != nil }
    }

    var hasPendingReminders: Bool {
        guard let compartments = compartments as? Set<Compartment> else { return false }
        for compartment in compartments {
            if let medication = compartment.medication {
                if let schedules = medication.reminderSchedules as? Set<ReminderSchedule> {
                    if schedules.contains(where: { $0.enabled }) {
                        return true
                    }
                }
            }
        }
        return false
    }
}
