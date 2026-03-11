import Foundation
import CoreData

extension Compartment {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Compartment> {
        return NSFetchRequest<Compartment>(entityName: "Compartment")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var width: Float
    @NSManaged public var height: Float
    @NSManaged public var depth: Float
    @NSManaged public var positionX: Float
    @NSManaged public var positionY: Float
    @NSManaged public var positionZ: Float
    @NSManaged public var colorHex: String?
    @NSManaged public var connectorMetadata: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var organizer: OrganizerDesign?
    @NSManaged public var medication: Medication?
}

extension Compartment : Identifiable {
}
