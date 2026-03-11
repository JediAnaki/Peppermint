import Foundation

struct SnapToGridCalculator {
    static let gridSize: Float = 5.0  // mm

    /// Snaps a value to the nearest 5mm grid point
    static func snap(_ value: Float) -> Float {
        return round(value / gridSize) * gridSize
    }

    /// Checks if a value is already snapped to the grid
    static func isSnapped(_ value: Float) -> Bool {
        return value.truncatingRemainder(dividingBy: gridSize) == 0
    }

    /// Snaps a 3D position to the grid
    static func snapPosition(x: Float, y: Float, z: Float) -> (x: Float, y: Float, z: Float) {
        return (snap(x), snap(y), snap(z))
    }

    /// Snaps dimensions to the grid
    static func snapDimensions(width: Float, height: Float, depth: Float) -> (width: Float, height: Float, depth: Float) {
        return (snap(width), snap(height), snap(depth))
    }

    /// Validates that all values are within acceptable range (5-100mm)
    static func isValidDimension(_ value: Float) -> Bool {
        let snapped = snap(value)
        return snapped >= 5.0 && snapped <= 100.0
    }

    /// Validates that a complete compartment configuration is valid
    static func isValidCompartment(width: Float, height: Float, depth: Float) -> Bool {
        return isValidDimension(width) && isValidDimension(height) && isValidDimension(depth)
    }
}
