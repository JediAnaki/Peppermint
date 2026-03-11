import Foundation
import CoreData

extension OrganizerDesign {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<OrganizerDesign> {
        return NSFetchRequest<OrganizerDesign>(entityName: "OrganizerDesign")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var compartments: NSSet?
    @NSManaged public var exportHistory: NSSet?
}

// MARK: Generated accessors for compartments
extension OrganizerDesign {
    @objc(addCompartmentsObject:)
    @NSManaged public func addToCompartments(_ value: Compartment)

    @objc(removeCompartmentsObject:)
    @NSManaged public func removeFromCompartments(_ value: Compartment)

    @objc(addCompartments:)
    @NSManaged public func addToCompartments(_ values: NSSet)

    @objc(removeCompartments:)
    @NSManaged public func removeFromCompartments(_ values: NSSet)
}

// MARK: Generated accessors for exportHistory
extension OrganizerDesign {
    @objc(addExportHistoryObject:)
    @NSManaged public func addToExportHistory(_ value: ExportHistory)

    @objc(removeExportHistoryObject:)
    @NSManaged public func removeFromExportHistory(_ value: ExportHistory)

    @objc(addExportHistory:)
    @NSManaged public func addToExportHistory(_ values: NSSet)

    @objc(removeExportHistory:)
    @NSManaged public func removeFromExportHistory(_ values: NSSet)
}

extension OrganizerDesign : Identifiable {
}
