//
//  Scene3DService.swift
//  Peppermint
//
//  Created by Claude on 2026-03-11.
//

import Foundation
import SceneKit
import UIKit

/// Service managing SceneKit 3D scene configuration and rendering
class Scene3DService {

    // MARK: - Constants

    static let targetFPS = 60
    static let cameraDistance: Float = 50.0
    static let defaultLightIntensity: CGFloat = 1000

    // MARK: - Singleton

    static let shared = Scene3DService()

    private init() {}

    // MARK: - Scene Setup

    /// Create and configure a new SceneKit scene with optimal settings
    /// - Returns: Configured SCNScene ready for rendering
    func createScene() -> SCNScene {
        let scene = SCNScene()

        // Add camera
        let cameraNode = createCamera()
        scene.rootNode.addChildNode(cameraNode)

        // Add lighting
        let lightNodes = createLighting()
        lightNodes.forEach { scene.rootNode.addChildNode($0) }

        // Add grid reference (optional, for development)
        #if DEBUG
        let gridNode = createGridReference()
        scene.rootNode.addChildNode(gridNode)
        #endif

        return scene
    }

    /// Configure SCNView for optimal Metal rendering performance
    /// - Parameter sceneView: The SCNView to configure
    func configureSceneView(_ sceneView: SCNView) {
        // Note: renderingAPI is read-only and defaults to Metal on modern iOS
        // sceneView.renderingAPI is set during SCNView initialization

        // Performance settings
        sceneView.preferredFramesPerSecond = Scene3DService.targetFPS
        sceneView.antialiasingMode = .multisampling2X  // Balance quality/performance

        // Enable default lighting for better visualization
        sceneView.autoenablesDefaultLighting = false  // We provide custom lighting

        // Allow user camera control via gestures
        sceneView.allowsCameraControl = false  // We'll handle gestures manually

        // Background color (Dark Mode compatible)
        sceneView.backgroundColor = UIColor.systemBackground

        // Enable statistics overlay in debug mode
        #if DEBUG
        sceneView.showsStatistics = true
        #endif
    }

    // MARK: - Camera Setup

    /// Create and position camera node
    /// - Returns: Configured camera node
    private func createCamera() -> SCNNode {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()

        // Position camera at an isometric-like angle
        cameraNode.position = SCNVector3(
            Scene3DService.cameraDistance,
            Scene3DService.cameraDistance * 0.75,
            Scene3DService.cameraDistance
        )

        // Look at origin (0, 0, 0)
        cameraNode.look(at: SCNVector3(0, 0, 0))

        // Configure camera properties
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 1000
        cameraNode.camera?.fieldOfView = 60

        return cameraNode
    }

    // MARK: - Lighting Setup

    /// Create lighting nodes for optimal 3D visualization
    /// - Returns: Array of light nodes
    private func createLighting() -> [SCNNode] {
        var lights: [SCNNode] = []

        // Ambient light (provides base illumination)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor(white: 0.4, alpha: 1.0)
        lights.append(ambientLightNode)

        // Directional light (main key light)
        let directionalLightNode = SCNNode()
        directionalLightNode.light = SCNLight()
        directionalLightNode.light?.type = .directional
        directionalLightNode.light?.intensity = Scene3DService.defaultLightIntensity
        directionalLightNode.light?.color = UIColor.white
        directionalLightNode.position = SCNVector3(10, 20, 10)
        directionalLightNode.look(at: SCNVector3(0, 0, 0))
        directionalLightNode.light?.castsShadow = true
        directionalLightNode.light?.shadowMode = .deferred
        lights.append(directionalLightNode)

        // Fill light (soften shadows)
        let fillLightNode = SCNNode()
        fillLightNode.light = SCNLight()
        fillLightNode.light?.type = .directional
        fillLightNode.light?.intensity = Scene3DService.defaultLightIntensity * 0.3
        fillLightNode.light?.color = UIColor.white
        fillLightNode.position = SCNVector3(-10, 10, -10)
        fillLightNode.look(at: SCNVector3(0, 0, 0))
        lights.append(fillLightNode)

        return lights
    }

    // MARK: - Grid Reference

    /// Create a grid reference for alignment (debug mode only)
    /// - Returns: Grid node
    private func createGridReference() -> SCNNode {
        let gridNode = SCNNode()

        // Create grid lines at 5mm intervals
        let gridSize = 100  // 100mm grid
        let gridStep: Float = 5.0  // 5mm per line

        let lineMaterial = SCNMaterial()
        lineMaterial.diffuse.contents = UIColor.systemGray.withAlphaComponent(0.3)

        // Create horizontal and vertical lines
        for i in stride(from: -gridSize, through: gridSize, by: Int(gridStep)) {
            // Horizontal line
            let hLine = SCNBox(width: CGFloat(gridSize * 2), height: 0.1, length: 0.1, chamferRadius: 0)
            hLine.materials = [lineMaterial]
            let hLineNode = SCNNode(geometry: hLine)
            hLineNode.position = SCNVector3(0, 0, Float(i))
            gridNode.addChildNode(hLineNode)

            // Vertical line
            let vLine = SCNBox(width: 0.1, height: 0.1, length: CGFloat(gridSize * 2), chamferRadius: 0)
            vLine.materials = [lineMaterial]
            let vLineNode = SCNNode(geometry: vLine)
            vLineNode.position = SCNVector3(Float(i), 0, 0)
            gridNode.addChildNode(vLineNode)
        }

        return gridNode
    }

    // MARK: - Material Creation

    /// Create a material with the specified color (Dark Mode compatible)
    /// - Parameter colorHex: Hex color string (e.g., "#CCCCCC")
    /// - Returns: Configured SCNMaterial
    func createMaterial(colorHex: String) -> SCNMaterial {
        let material = SCNMaterial()

        // Convert hex to UIColor
        let color = UIColor(hex: colorHex) ?? UIColor.systemGray
        material.diffuse.contents = color

        // Add slight specular highlight for depth
        material.specular.contents = UIColor.white.withAlphaComponent(0.2)
        material.shininess = 0.1

        // Enable lighting response
        material.lightingModel = .blinn

        return material
    }
}

// MARK: - UIColor Extension

extension UIColor {
    /// Initialize UIColor from hex string
    /// - Parameter hex: Hex color string (e.g., "#CCCCCC" or "CCCCCC")
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
