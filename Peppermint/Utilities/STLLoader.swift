//
//  STLLoader.swift
//  Peppermint
//
//  Created for Feature: OpenSCAD-Based STL Export with Cloud Sync
//  Phase 3 - User Story 1: Binary STL parser for SceneKit rendering
//

import Foundation
import SceneKit

// MARK: - STL Error Types

/// Errors that can occur during STL parsing
enum STLError: Error, LocalizedError {
    case invalidFormat
    case corruptedData
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid STL file format"
        case .corruptedData:
            return "STL data is corrupted or incomplete"
        case .unsupportedVersion:
            return "Unsupported STL version (only binary STL supported)"
        }
    }
}

// MARK: - STL Loader

/// Utility for loading binary STL files into SceneKit geometry
struct STLLoader {

    // MARK: - Public API

    /// Loads binary STL data into SceneKit geometry with color and transparency
    ///
    /// **Binary STL Format**:
    /// - Header: 80 bytes (ignored, typically ASCII description)
    /// - Triangle count: 4 bytes (uint32, little-endian)
    /// - Triangles: 50 bytes each × triangle count
    ///   - Normal vector: 3 × float32 (12 bytes)
    ///   - Vertex 1: 3 × float32 (12 bytes)
    ///   - Vertex 2: 3 × float32 (12 bytes)
    ///   - Vertex 3: 3 × float32 (12 bytes)
    ///   - Attribute byte count: uint16 (2 bytes, unused)
    ///
    /// **SceneKit Integration**:
    /// - Creates SCNGeometry from parsed vertices and normals
    /// - Applies material with specified color and transparency
    /// - Uses physically-based rendering (PBR) for realistic lighting
    ///
    /// - Parameters:
    ///   - data: Binary STL file data
    ///   - color: UIColor for the mesh material
    ///   - transparency: Alpha value (0.0 = invisible, 1.0 = opaque)
    ///
    /// - Returns: SCNNode containing the STL geometry with applied material
    ///
    /// - Throws: `STLError` if parsing fails
    static func loadSTL(data: Data, color: UIColor, transparency: CGFloat = 1.0) throws -> SCNNode {
        // Validate minimum file size (header + triangle count)
        guard data.count >= 84 else {
            throw STLError.invalidFormat
        }

        // Skip 80-byte header
        let headerEndIndex = 80

        // Read triangle count (uint32, little-endian)
        let triangleCountData = data.subdata(in: headerEndIndex..<(headerEndIndex + 4))
        let triangleCount = triangleCountData.withUnsafeBytes { $0.load(as: UInt32.self) }

        print("📦 Loading STL: \(triangleCount) triangles")

        // Validate file size matches expected triangle data
        let expectedSize = 84 + Int(triangleCount) * 50
        guard data.count >= expectedSize else {
            throw STLError.corruptedData
        }

        // Parse triangles
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []

        for i in 0..<Int(triangleCount) {
            let triangleOffset = 84 + i * 50

            // Read normal vector (3 floats, 12 bytes)
            let normalData = data.subdata(in: triangleOffset..<(triangleOffset + 12))
            let normal = parseVector3(from: normalData)

            // Read vertex 1 (3 floats, 12 bytes)
            let vertex1Data = data.subdata(in: (triangleOffset + 12)..<(triangleOffset + 24))
            let vertex1 = parseVector3(from: vertex1Data)

            // Read vertex 2 (3 floats, 12 bytes)
            let vertex2Data = data.subdata(in: (triangleOffset + 24)..<(triangleOffset + 36))
            let vertex2 = parseVector3(from: vertex2Data)

            // Read vertex 3 (3 floats, 12 bytes)
            let vertex3Data = data.subdata(in: (triangleOffset + 36)..<(triangleOffset + 48))
            let vertex3 = parseVector3(from: vertex3Data)

            // Add vertices (3 per triangle)
            vertices.append(vertex1)
            vertices.append(vertex2)
            vertices.append(vertex3)

            // Add normals (same normal for all 3 vertices)
            normals.append(normal)
            normals.append(normal)
            normals.append(normal)

            // Note: Last 2 bytes (attribute byte count) are unused in standard STL
        }

        print("✅ Parsed \(vertices.count) vertices, \(normals.count) normals")

        // Create SCNGeometry from vertices and normals
        let geometry = try createGeometry(vertices: vertices, normals: normals)

        // Apply material with color and transparency
        let material = SCNMaterial()
        material.diffuse.contents = color.withAlphaComponent(transparency)
        material.lightingModel = .physicallyBased  // PBR for realistic rendering
        material.metalness.contents = 0.1  // Slight metallic look
        material.roughness.contents = 0.7  // Matte finish
        material.isDoubleSided = true  // Render both sides of triangles

        // Enable transparency if alpha < 1.0
        if transparency < 1.0 {
            material.transparency = transparency
            material.blendMode = .alpha
        }

        geometry.materials = [material]

        // Create node
        let node = SCNNode(geometry: geometry)

        print("✅ Created SceneKit node with \(triangleCount) triangles")

        return node
    }

    // MARK: - Helper Methods

    /// Parses 3D vector from 12 bytes of float32 data (little-endian)
    private static func parseVector3(from data: Data) -> SCNVector3 {
        let floats = data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float32.self))
        }

        guard floats.count >= 3 else {
            return SCNVector3(0, 0, 0)
        }

        return SCNVector3(floats[0], floats[1], floats[2])
    }

    /// Creates SCNGeometry from vertex and normal arrays
    ///
    /// **SceneKit Geometry Construction**:
    /// 1. Create SCNGeometrySource for vertices (semantic: .vertex)
    /// 2. Create SCNGeometrySource for normals (semantic: .normal)
    /// 3. Create SCNGeometryElement for indices (primitive: .triangles)
    /// 4. Combine into SCNGeometry
    ///
    /// - Parameters:
    ///   - vertices: Array of vertex positions
    ///   - normals: Array of normal vectors (must match vertices count)
    ///
    /// - Returns: SCNGeometry ready for rendering
    ///
    /// - Throws: `STLError.corruptedData` if vertices/normals count mismatch
    private static func createGeometry(vertices: [SCNVector3], normals: [SCNVector3]) throws -> SCNGeometry {
        guard vertices.count == normals.count else {
            throw STLError.corruptedData
        }

        // Create vertex source
        let vertexData = Data(bytes: vertices, count: vertices.count * MemoryLayout<SCNVector3>.size)
        let vertexSource = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector3>.size
        )

        // Create normal source
        let normalData = Data(bytes: normals, count: normals.count * MemoryLayout<SCNVector3>.size)
        let normalSource = SCNGeometrySource(
            data: normalData,
            semantic: .normal,
            vectorCount: normals.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector3>.size
        )

        // Create indices (sequential, no index buffer needed for simple triangle list)
        let indices: [Int32] = Array(0..<Int32(vertices.count))
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: vertices.count / 3,
            bytesPerIndex: MemoryLayout<Int32>.size
        )

        // Create geometry
        let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])

        return geometry
    }
}
