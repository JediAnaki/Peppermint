import Foundation
import CoreData

extension ExportHistory {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExportHistory> {
        return NSFetchRequest<ExportHistory>(entityName: "ExportHistory")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var exportedAt: Date?
    @NSManaged public var fileName: String?
    @NSManaged public var fileSize: Int64
    @NSManaged public var compartmentCount: Int16
    @NSManaged public var exportDuration: Double
    @NSManaged public var organizer: OrganizerDesign?
}

extension ExportHistory : Identifiable {
}
