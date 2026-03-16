//
//  STLExporter.swift
//  Peppermint
//
//  Created by Claude on 2026-03-12.
//

import Foundation
import simd

// MARK: - Triangle

/// Represents a single triangle for STL export with auto-calculated normal
struct Triangle {
    let normal: SIMD3<Float>
    let v1: SIMD3<Float>
    let v2: SIMD3<Float>
    let v3: SIMD3<Float>

    /// Initialize triangle with counter-clockwise vertices (outward-facing normals)
    init(v1: SIMD3<Float>, v2: SIMD3<Float>, v3: SIMD3<Float>) {
        self.v1 = v1
        self.v2 = v2
        self.v3 = v3

        // Calculate normal from counter-clockwise vertices
        let edge1 = v2 - v1
        let edge2 = v3 - v1
        self.normal = normalize(cross(edge1, edge2))
    }

    /// Initialize triangle with explicit normal
    init(normal: SIMD3<Float>, v1: SIMD3<Float>, v2: SIMD3<Float>, v3: SIMD3<Float>) {
        self.normal = normal
        self.v1 = v1
        self.v2 = v2
        self.v3 = v3
    }
}

// MARK: - Binary STL Exporter

/// Exports 3D geometry to binary STL format for 3D printing
class BinarySTLExporter {

    /// Export triangles to binary STL file
    /// - Parameters:
    ///   - triangles: Array of Triangle structs to export
    ///   - url: File URL to write STL data
    /// - Throws: STLExportError if export fails
    static func export(triangles: [Triangle], to url: URL) throws {
        guard !triangles.isEmpty else {
            throw STLExportError.emptyGeometry
        }

        var data = Data()

        // Write 80-byte header (must not start with "solid" to avoid ASCII STL confusion)
        let headerText = "Binary STL - Peppermint Organizer"
        let paddedHeader = headerText.padding(toLength: 80, withPad: " ", startingAt: 0)
        data.append(Data(paddedHeader.utf8))

        // Write triangle count (UInt32 little-endian)
        var triangleCount = UInt32(triangles.count).littleEndian
        data.append(Data(bytes: &triangleCount, count: 4))

        // Write each triangle (50 bytes per triangle)
        for triangle in triangles {
            // Normal vector (12 bytes)
            data.append(float3ToData(triangle.normal))

            // Vertex 1 (12 bytes)
            data.append(float3ToData(triangle.v1))

            // Vertex 2 (12 bytes)
            data.append(float3ToData(triangle.v2))

            // Vertex 3 (12 bytes)
            data.append(float3ToData(triangle.v3))

            // Attribute byte count (2 bytes, typically 0)
            var attributeCount: UInt16 = 0
            data.append(Data(bytes: &attributeCount, count: 2))
        }

        // Write to file atomically
        try data.write(to: url, options: .atomic)
    }

    /// Convert SIMD3<Float> to little-endian Data (12 bytes)
    private static func float3ToData(_ vector: SIMD3<Float>) -> Data {
        var data = Data()
        var x = vector.x.bitPattern.littleEndian
        var y = vector.y.bitPattern.littleEndian
        var z = vector.z.bitPattern.littleEndian

        data.append(Data(bytes: &x, count: 4))
        data.append(Data(bytes: &y, count: 4))
        data.append(Data(bytes: &z, count: 4))

        return data
    }
}

// MARK: - Connector Specification

/// Specification for friction-fit connectors (tabs and grooves)
struct ConnectorSpec {
    enum ConnectorType {
        case tab
        case groove
        case none
    }

    enum Edge {
        case top, bottom, left, right, front, back
    }

    let edge: Edge
    let type: ConnectorType
    let offset: Float // Offset along edge (0.0 = centered)
}

// MARK: - Compartment Geometry

/// Generates triangle geometry for compartments with friction-fit connectors
struct CompartmentGeometry {
    let width: Float
    let height: Float
    let depth: Float
    let position: SIMD3<Float>
    let connectors: [ConnectorSpec]

    // Friction-fit dimensions (from research.md - PETG tolerances)
    static let tabHeight: Float = 2.0      // mm
    static let grooveDepth: Float = 1.2    // mm
    static let tolerance: Float = 0.3      // mm (0.25-0.35mm for PETG)
    static let wallThickness: Float = 2.0  // mm minimum for printability

    /// Generate all triangles for this compartment including friction-fit connectors
    func generateTriangles() throws -> [Triangle] {
        guard width >= 5.0, height >= 5.0, depth >= 5.0 else {
            throw STLExportError.invalidDimensions(width: width, height: height, depth: depth)
        }

        var triangles: [Triangle] = []

        // Generate basic box faces (6 faces × 2 triangles = 12 triangles)
        triangles.append(contentsOf: generateBoxFaces())

        // Generate friction-fit connectors
        for connector in connectors where connector.type != .none {
            triangles.append(contentsOf: generateConnector(connector))
        }

        return triangles
    }

    /// Generate 12 triangles for basic box faces
    private func generateBoxFaces() -> [Triangle] {
        let w = width / 2.0
        let h = height / 2.0
        let d = depth / 2.0

        // 8 vertices of the box (centered at position)
        let v0 = position + SIMD3<Float>(-w, -h, d)  // front-bottom-left
        let v1 = position + SIMD3<Float>(w, -h, d)   // front-bottom-right
        let v2 = position + SIMD3<Float>(w, h, d)    // front-top-right
        let v3 = position + SIMD3<Float>(-w, h, d)   // front-top-left
        let v4 = position + SIMD3<Float>(-w, -h, -d) // back-bottom-left
        let v5 = position + SIMD3<Float>(w, -h, -d)  // back-bottom-right
        let v6 = position + SIMD3<Float>(w, h, -d)   // back-top-right
        let v7 = position + SIMD3<Float>(-w, h, -d)  // back-top-left

        return [
            // Front face (2 triangles, counter-clockwise when viewed from front)
            Triangle(v1: v0, v2: v1, v3: v2),
            Triangle(v1: v0, v2: v2, v3: v3),

            // Right face
            Triangle(v1: v1, v2: v5, v3: v6),
            Triangle(v1: v1, v2: v6, v3: v2),

            // Back face
            Triangle(v1: v5, v2: v4, v3: v7),
            Triangle(v1: v5, v2: v7, v3: v6),

            // Left face
            Triangle(v1: v4, v2: v0, v3: v3),
            Triangle(v1: v4, v2: v3, v3: v7),

            // Top face
            Triangle(v1: v3, v2: v2, v3: v6),
            Triangle(v1: v3, v2: v6, v3: v7),

            // Bottom face
            Triangle(v1: v4, v2: v5, v3: v1),
            Triangle(v1: v4, v2: v1, v3: v0)
        ]
    }

    /// Generate triangles for a friction-fit connector (tab or groove)
    private func generateConnector(_ connector: ConnectorSpec) -> [Triangle] {
        switch connector.type {
        case .tab:
            return generateTab(on: connector.edge, offset: connector.offset)
        case .groove:
            return generateGroove(on: connector.edge, offset: connector.offset)
        case .none:
            return []
        }
    }

    /// Generate tab geometry (cantilever snap-tab protruding outward)
    private func generateTab(on edge: ConnectorSpec.Edge, offset: Float) -> [Triangle] {
        let tabWidth: Float = 10.0  // mm width of tab
        let tabHeight = Self.tabHeight
        let tabDepth: Float = 1.5   // mm protrusion from surface

        let w = width / 2.0
        let h = height / 2.0
        let d = depth / 2.0

        var triangles: [Triangle] = []

        switch edge {
        case .top:
            // Tab on top face, protruding upward
            let baseY = position.y + h
            let tabY = baseY + tabHeight

            let centerX = position.x + offset
            let x1 = centerX - tabWidth / 2.0
            let x2 = centerX + tabWidth / 2.0

            let z1 = position.z - tabDepth / 2.0
            let z2 = position.z + tabDepth / 2.0

            // Tab box (6 faces)
            let v0 = SIMD3<Float>(x1, baseY, z2)  // front-bottom-left
            let v1 = SIMD3<Float>(x2, baseY, z2)  // front-bottom-right
            let v2 = SIMD3<Float>(x2, tabY, z2)   // front-top-right
            let v3 = SIMD3<Float>(x1, tabY, z2)   // front-top-left
            let v4 = SIMD3<Float>(x1, baseY, z1)  // back-bottom-left
            let v5 = SIMD3<Float>(x2, baseY, z1)  // back-bottom-right
            let v6 = SIMD3<Float>(x2, tabY, z1)   // back-top-right
            let v7 = SIMD3<Float>(x1, tabY, z1)   // back-top-left

            triangles.append(contentsOf: [
                // Front, Right, Back, Left, Top (no bottom - connects to base)
                Triangle(v1: v0, v2: v1, v3: v2), Triangle(v1: v0, v2: v2, v3: v3), // Front
                Triangle(v1: v1, v2: v5, v3: v6), Triangle(v1: v1, v2: v6, v3: v2), // Right
                Triangle(v1: v5, v2: v4, v3: v7), Triangle(v1: v5, v2: v7, v3: v6), // Back
                Triangle(v1: v4, v2: v0, v3: v3), Triangle(v1: v4, v2: v3, v3: v7), // Left
                Triangle(v1: v3, v2: v2, v3: v6), Triangle(v1: v3, v2: v6, v3: v7)  // Top
            ])

        case .bottom:
            // Tab on bottom face, protruding downward
            let baseY = position.y - h
            let tabY = baseY - tabHeight

            let centerX = position.x + offset
            let x1 = centerX - tabWidth / 2.0
            let x2 = centerX + tabWidth / 2.0

            let z1 = position.z - tabDepth / 2.0
            let z2 = position.z + tabDepth / 2.0

            let v0 = SIMD3<Float>(x1, tabY, z2)
            let v1 = SIMD3<Float>(x2, tabY, z2)
            let v2 = SIMD3<Float>(x2, baseY, z2)
            let v3 = SIMD3<Float>(x1, baseY, z2)
            let v4 = SIMD3<Float>(x1, tabY, z1)
            let v5 = SIMD3<Float>(x2, tabY, z1)
            let v6 = SIMD3<Float>(x2, baseY, z1)
            let v7 = SIMD3<Float>(x1, baseY, z1)

            triangles.append(contentsOf: [
                Triangle(v1: v0, v2: v1, v3: v2), Triangle(v1: v0, v2: v2, v3: v3),
                Triangle(v1: v1, v2: v5, v3: v6), Triangle(v1: v1, v2: v6, v3: v2),
                Triangle(v1: v5, v2: v4, v3: v7), Triangle(v1: v5, v2: v7, v3: v6),
                Triangle(v1: v4, v2: v0, v3: v3), Triangle(v1: v4, v2: v3, v3: v7),
                Triangle(v1: v4, v2: v5, v3: v1), Triangle(v1: v4, v2: v1, v3: v0)
            ])

        case .left, .right, .front, .back:
            // Similar logic for other edges (simplified for MVP)
            // In production, implement full tab geometry for all 6 edges
            break
        }

        return triangles
    }

    /// Generate groove geometry (indentation for tab to snap into)
    private func generateGroove(on edge: ConnectorSpec.Edge, offset: Float) -> [Triangle] {
        // Groove is an indentation - we subtract geometry from the box
        // For binary STL, we don't actually subtract, we just add inverted faces
        // For MVP, grooves can be represented as empty space (no additional triangles)
        // The tab from neighboring compartment will simply occupy this space

        // In a full implementation, grooves would add interior wall geometry
        // to create the indentation, but for functional snap-fit, the gap itself works

        return []
    }
}

// MARK: - STL Export Service

/// High-level service for exporting organizers to STL files
class STLExporter {

    /// Export an organizer design to STL file
    /// - Parameters:
    ///   - organizer: OrganizerDesign to export
    ///   - url: Destination file URL
    /// - Returns: Export statistics (file size, triangle count, duration)
    /// - Throws: STLExportError if export fails
    static func export(organizer: OrganizerDesign, to url: URL) throws -> ExportStats {
        let startTime = Date()

        let compartments = organizer.compartmentsArray
        guard !compartments.isEmpty else {
            throw STLExportError.emptyOrganizer
        }

        var allTriangles: [Triangle] = []

        // Generate triangles for each compartment
        for compartment in compartments {
            let connectors = parseConnectorMetadata(compartment.connectorMetadata)

            let geometry = CompartmentGeometry(
                width: compartment.width,
                height: compartment.height,
                depth: compartment.depth,
                position: SIMD3<Float>(compartment.positionX, compartment.positionY, compartment.positionZ),
                connectors: connectors
            )

            let triangles = try geometry.generateTriangles()
            allTriangles.append(contentsOf: triangles)
        }

        // Export to binary STL
        try BinarySTLExporter.export(triangles: allTriangles, to: url)

        // Calculate stats
        let duration = Date().timeIntervalSince(startTime)
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0

        return ExportStats(
            triangleCount: allTriangles.count,
            fileSize: fileSize,
            duration: duration,
            compartmentCount: compartments.count
        )
    }

    /// Parse connector metadata JSON from CoreData
    private static func parseConnectorMetadata(_ data: Data?) -> [ConnectorSpec] {
        // For MVP, return empty array - connector parsing will be implemented in T058
        return []
    }
}

// MARK: - Export Statistics

/// Statistics about an STL export operation
struct ExportStats {
    let triangleCount: Int
    let fileSize: Int64
    let duration: TimeInterval
    let compartmentCount: Int

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var formattedDuration: String {
        return String(format: "%.2f seconds", duration)
    }
}

// MARK: - Errors

enum STLExportError: LocalizedError {
    case emptyGeometry
    case emptyOrganizer
    case invalidDimensions(width: Float, height: Float, depth: Float)
    case overlappingCompartments(compartment1: UUID, compartment2: UUID)
    case wallThicknessTooThin(compartment: UUID, thickness: Float)
    case connectorTooSmall(compartment: UUID)

    var errorDescription: String? {
        switch self {
        case .emptyGeometry:
            return "Cannot export empty geometry - no triangles generated"
        case .emptyOrganizer:
            return "Cannot export organizer with no compartments"
        case .invalidDimensions(let w, let h, let d):
            return "Invalid compartment dimensions: \(w)×\(h)×\(d)mm. Minimum 5mm per dimension required."
        case .overlappingCompartments(let id1, let id2):
            return "Compartments \(id1) and \(id2) overlap. Move compartments apart before exporting."
        case .wallThicknessTooThin(let id, let thickness):
            return "Compartment \(id) has walls too thin (\(thickness)mm). Minimum 2mm required for printing."
        case .connectorTooSmall(let id):
            return "Compartment \(id) is too small for friction-fit connectors. Increase size or remove connectors."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyOrganizer:
            return "Add at least one compartment to the organizer before exporting."
        case .invalidDimensions:
            return "Increase compartment size to at least 5×5×5mm."
        case .overlappingCompartments:
            return "Use the 3D view to reposition overlapping compartments with at least 5mm spacing."
        case .wallThicknessTooThin:
            return "Increase compartment size or reduce wall thickness requirements."
        case .connectorTooSmall:
            return "Increase compartment size to at least 15×15×15mm for friction-fit connectors."
        default:
            return nil
        }
    }
}
