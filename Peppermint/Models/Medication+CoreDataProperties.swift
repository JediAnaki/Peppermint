import Foundation
import CoreData

extension Medication {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Medication> {
        return NSFetchRequest<Medication>(entityName: "Medication")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var expirationDate: Date?
    @NSManaged public var category: String?
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var compartment: Compartment?
    @NSManaged public var reminderSchedules: NSSet?
}

// MARK: Generated accessors for reminderSchedules
extension Medication {
    @objc(addReminderSchedulesObject:)
    @NSManaged public func addToReminderSchedules(_ value: ReminderSchedule)

    @objc(removeReminderSchedulesObject:)
    @NSManaged public func removeFromReminderSchedules(_ value: ReminderSchedule)

    @objc(addReminderSchedules:)
    @NSManaged public func addToReminderSchedules(_ values: NSSet)

    @objc(removeReminderSchedules:)
    @NSManaged public func removeFromReminderSchedules(_ values: NSSet)
}

extension Medication : Identifiable {
}
