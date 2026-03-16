//
//  Medication+Visualization.swift
//  Peppermint
//
//  Created for Feature: OpenSCAD-Based STL Export with Cloud Sync
//  Phase 6 - User Story 4: Pill visualization in 3D preview
//

import Foundation

// MARK: - Medication Visualization Extension (T093-T094)

extension Medication {

    // MARK: - Visualization Properties

    /// T093: Whether this medication should appear in 3D preview
    ///
    /// **Trigger**: Medication.name is filled (FR-017)
    ///
    /// Pills appear in preview ONLY when:
    /// - User has entered a medication name (minimal required field)
    /// - Preview toggle is enabled (showPillsInPreview = true)
    ///
    /// **Returns**: `true` if medication has a non-empty name, `false` otherwise
    var shouldVisualize: Bool {
        guard let name = name, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        return true
    }

    // MARK: - Pill Geometry

    /// T094: Pill geometry for OpenSCAD API
    ///
    /// **Codable struct** for sending pill shape data to server for 3D rendering.
    ///
    /// **Shapes**:
    /// - `round`: Spherical/circular pills (default)
    /// - `oblong`: Capsule-shaped pills
    /// - `capsule`: Two-tone capsules
    /// - `oval`: Elliptical pills
    ///
    /// **Defaults**:
    /// - Shape: "round" if not specified
    /// - Diameter: 8.0mm (standard pill size)
    /// - Length: 8.0mm (for oblong/capsule shapes)
    struct PillGeometry: Codable {
        let shape: String       // "round", "oblong", "capsule", "oval"
        let diameter: Float     // mm (width for oblong/oval)
        let length: Float       // mm (for oblong/capsule, ignored for round)

        enum CodingKeys: String, CodingKey {
            case shape
            case diameter
            case length
        }
    }

    /// Returns pill geometry configuration for this medication
    ///
    /// **Usage**: Send to OpenSCAD API when `includePills: true`
    ///
    /// **Example**:
    /// ```swift
    /// if medication.shouldVisualize {
    ///     let geometry = medication.pillGeometry
    ///     // Send to server: { "shape": "round", "diameter": 8.0, "length": 8.0 }
    /// }
    /// ```
    var pillGeometry: PillGeometry {
        return PillGeometry(
            shape: pillShape ?? "round",      // Default: round pills
            diameter: pillDiameter,           // From CoreData attribute
            length: pillLength                // From CoreData attribute
        )
    }

    // MARK: - Default Values

    /// Default pill shape if not specified
    ///
    /// **Note**: CoreData attribute has default value "round",
    /// but this property provides fallback if attribute is nil
    static let defaultPillShape = "round"

    /// Default pill diameter (8mm - standard pill size)
    static let defaultPillDiameter: Float = 8.0

    /// Default pill length (8mm - same as diameter for round pills)
    static let defaultPillLength: Float = 8.0

    // MARK: - Validation

    /// Validates pill geometry parameters
    ///
    /// **Constraints**:
    /// - Diameter: 4mm to 20mm (realistic pill sizes)
    /// - Length: 4mm to 30mm (for oblong/capsule)
    /// - Shape: Must be one of ["round", "oblong", "capsule", "oval"]
    ///
    /// **Returns**: `true` if geometry is valid, `false` otherwise
    var hasValidPillGeometry: Bool {
        // Check shape
        let validShapes = ["round", "oblong", "capsule", "oval"]
        guard let shape = pillShape, validShapes.contains(shape) else {
            return false
        }

        // Check diameter range (4mm to 20mm)
        guard pillDiameter >= 4.0 && pillDiameter <= 20.0 else {
            return false
        }

        // Check length range (4mm to 30mm)
        guard pillLength >= 4.0 && pillLength <= 30.0 else {
            return false
        }

        return true
    }

    /// Returns a user-friendly description of the pill shape
    ///
    /// **Example**: "Round pill (8mm)"
    var pillShapeDescription: String {
        let shape = pillShape ?? Medication.defaultPillShape
        let diameter = pillDiameter

        switch shape {
        case "round":
            return "Round pill (\(Int(diameter))mm)"
        case "oblong":
            return "Oblong pill (\(Int(diameter))×\(Int(pillLength))mm)"
        case "capsule":
            return "Capsule (\(Int(diameter))×\(Int(pillLength))mm)"
        case "oval":
            return "Oval pill (\(Int(diameter))×\(Int(pillLength))mm)"
        default:
            return "Pill (\(Int(diameter))mm)"
        }
    }
}
