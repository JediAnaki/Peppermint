import Foundation
import CoreData
import simd

@objc(Compartment)
public class Compartment: NSManagedObject {
    // Computed properties
    var volume: Float {
        return (width * height * depth)
    }

    var hasMedication: Bool {
        return medication != nil
    }

    var neighbors: [Compartment] {
        guard let organizer = organizer else { return [] }
        guard let allCompartments = organizer.compartments as? Set<Compartment> else { return [] }

        let gridSize: Float = 5.0
        return allCompartments.filter { other in
            guard other.id != self.id else { return false }

            // Check if compartments are adjacent (within 5mm on any axis)
            let dx = abs(other.positionX - self.positionX)
            let dy = abs(other.positionY - self.positionY)
            let dz = abs(other.positionZ - self.positionZ)

            // Adjacent if one dimension matches and others differ by compartment size
            let xAligned = dx < gridSize && (dy <= (self.height + other.height) / 2 + gridSize) && (dz <= (self.depth + other.depth) / 2 + gridSize)
            let yAligned = dy < gridSize && (dx <= (self.width + other.width) / 2 + gridSize) && (dz <= (self.depth + other.depth) / 2 + gridSize)
            let zAligned = dz < gridSize && (dx <= (self.width + other.width) / 2 + gridSize) && (dy <= (self.height + other.height) / 2 + gridSize)

            return xAligned || yAligned || zAligned
        }
    }

    var boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>) {
        let min = SIMD3<Float>(positionX, positionY, positionZ)
        let max = SIMD3<Float>(positionX + width, positionY + height, positionZ + depth)
        return (min, max)
    }

    func intersects(_ other: Compartment) -> Bool {
        let selfBounds = self.boundingBox
        let otherBounds = other.boundingBox

        return !(selfBounds.max.x <= otherBounds.min.x ||
                selfBounds.min.x >= otherBounds.max.x ||
                selfBounds.max.y <= otherBounds.min.y ||
                selfBounds.min.y >= otherBounds.max.y ||
                selfBounds.max.z <= otherBounds.min.z ||
                selfBounds.min.z >= otherBounds.max.z)
    }
}
