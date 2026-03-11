import Foundation
import CoreData

extension ReminderSchedule {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReminderSchedule> {
        return NSFetchRequest<ReminderSchedule>(entityName: "ReminderSchedule")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var enabled: Bool
    @NSManaged public var frequency: String?
    @NSManaged public var timesOfDay: Data?
    @NSManaged public var daysOfWeek: Data?
    @NSManaged public var customDates: Data?
    @NSManaged public var soundName: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var medication: Medication?
}

extension ReminderSchedule : Identifiable {
}
