//
//  Scene3DView.swift
//  Peppermint
//
//  Created by Claude on 2026-03-11.
//

import SwiftUI
import SceneKit

/// UIViewRepresentable wrapper for SCNView with gesture support for 3D organizer construction
struct Scene3DView: UIViewRepresentable {

    // MARK: - Bindings

    @Binding var organizer: OrganizerDesign?
    @Binding var selectedCompartment: Compartment?
    var sceneViewRef: Binding<SCNView?>? = nil

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()

        // Create and configure scene
        let scene = Scene3DService.shared.createScene()
        sceneView.scene = scene

        // Configure SceneView for optimal performance
        Scene3DService.shared.configureSceneView(sceneView)

        // Add gesture recognizers
        context.coordinator.setupGestures(for: sceneView)

        // Store reference to scene view in coordinator
        context.coordinator.sceneView = sceneView

        // Pass reference to parent if binding provided
        if let sceneViewRef = sceneViewRef {
            DispatchQueue.main.async {
                sceneViewRef.wrappedValue = sceneView
            }
        }

        return sceneView
    }

    func updateUIView(_ sceneView: SCNView, context: Context) {
        // Update compartments in scene when organizer changes
        context.coordinator.updateCompartments(organizer, in: sceneView)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var parent: Scene3DView
        var sceneView: SCNView?

        // Gesture state
        private var lastPanTranslation: CGPoint = .zero
        private var cameraDistance: Float = Scene3DService.cameraDistance
        private var cameraAngleX: Float = 0.0
        private var cameraAngleY: Float = 0.0

        // Compartment nodes mapping
        private var compartmentNodes: [UUID: SCNNode] = [:]

        init(parent: Scene3DView) {
            self.parent = parent
            super.init()
        }

        // MARK: - Gesture Setup

        func setupGestures(for sceneView: SCNView) {
            // Pinch gesture for zoom
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            sceneView.addGestureRecognizer(pinchGesture)

            // Rotation gesture for orbiting camera
            let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
            sceneView.addGestureRecognizer(rotationGesture)

            // Pan gesture for camera movement
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            panGesture.minimumNumberOfTouches = 1
            panGesture.maximumNumberOfTouches = 1
            sceneView.addGestureRecognizer(panGesture)

            // Tap gesture for selection
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            sceneView.addGestureRecognizer(tapGesture)

            // Allow gestures to work simultaneously
            pinchGesture.delegate = self
            rotationGesture.delegate = self
            panGesture.delegate = self
        }

        // MARK: - Compartment Rendering

        func updateCompartments(_ organizer: OrganizerDesign?, in sceneView: SCNView) {
            guard let organizer = organizer else {
                // Clear all compartments if no organizer
                compartmentNodes.values.forEach { $0.removeFromParentNode() }
                compartmentNodes.removeAll()
                return
            }

            let currentCompartments = organizer.compartmentsArray
            var currentIDs = Set<UUID>()

            // Add or update compartments
            for compartment in currentCompartments {
                guard let id = compartment.id else { continue }
                currentIDs.insert(id)

                if let existingNode = compartmentNodes[id] {
                    // Update existing node position/appearance
                    updateCompartmentNode(existingNode, with: compartment)
                } else {
                    // Create new node
                    let node = createCompartmentNode(for: compartment)
                    sceneView.scene?.rootNode.addChildNode(node)
                    compartmentNodes[id] = node
                }
            }

            // Remove deleted compartments
            let removedIDs = Set(compartmentNodes.keys).subtracting(currentIDs)
            for id in removedIDs {
                compartmentNodes[id]?.removeFromParentNode()
                compartmentNodes.removeValue(forKey: id)
            }

            // Update selection highlights
            updateSelectionHighlights()
        }

        /// Create a SceneKit node for a compartment with procedural geometry
        private func createCompartmentNode(for compartment: Compartment) -> SCNNode {
            let node = SCNNode()

            // Generate procedural geometry with vertices and indices
            let geometry = createProceduralBoxGeometry(
                width: compartment.width,
                height: compartment.height,
                depth: compartment.depth
            )

            // Apply material with compartment color
            let material = Scene3DService.shared.createMaterial(colorHex: compartment.colorHex ?? "#CCCCCC")
            geometry.materials = [material]

            node.geometry = geometry
            node.position = SCNVector3(
                compartment.positionX,
                compartment.positionY,
                compartment.positionZ
            )

            // Store compartment ID in node name for hit testing
            node.name = compartment.id?.uuidString

            // Add medication label if medication exists
            if let medication = compartment.medication, let medicationName = medication.name {
                let labelNode = createMedicationLabel(
                    text: medicationName,
                    compartmentHeight: compartment.height,
                    medication: medication
                )
                node.addChildNode(labelNode)
            }

            return node
        }

        /// Create a 3D text label for medication name
        private func createMedicationLabel(text: String, compartmentHeight: Float, medication: Medication) -> SCNNode {
            let textGeometry = SCNText(string: text, extrusionDepth: 0.5)

            // Configure text appearance for Dark Mode compatibility
            textGeometry.font = UIFont.preferredFont(forTextStyle: .caption1)
            textGeometry.flatness = 0.1
            textGeometry.chamferRadius = 0.1

            // Apply material with label color (Dark Mode compatible)
            let textMaterial = SCNMaterial()
            textMaterial.diffuse.contents = UIColor.label
            textMaterial.lightingModel = .constant // Always visible regardless of lighting
            textGeometry.materials = [textMaterial]

            let textNode = SCNNode(geometry: textGeometry)

            // Position above the compartment
            let labelHeight: Float = 2.0
            textNode.position = SCNVector3(0, compartmentHeight / 2 + labelHeight, 0)

            // Scale down the text to reasonable size
            let scale: Float = 0.015
            textNode.scale = SCNVector3(scale, scale, scale)

            // Center the text horizontally
            let boundingBox = textGeometry.boundingBox
            let textWidth = (boundingBox.max.x - boundingBox.min.x) * scale
            textNode.position.x = -textWidth / 2

            // Add billboard constraint to always face camera
            let billboardConstraint = SCNBillboardConstraint()
            billboardConstraint.freeAxes = [.Y] // Only rotate around Y axis
            textNode.constraints = [billboardConstraint]

            // Add expiration warning indicator if needed
            var xOffset: Float = -2.0
            if medication.isExpiringSoon || medication.isExpired {
                let warningNode = createExpirationWarningIndicator(for: medication)
                warningNode.position = SCNVector3(xOffset, 1, 0) // To the left of label
                textNode.addChildNode(warningNode)
                xOffset -= 2.5 // Move next indicator further left
            }

            // Add reminder indicator if active reminders exist
            if medication.hasActiveReminders {
                let reminderNode = createReminderIndicator()
                reminderNode.position = SCNVector3(xOffset, 1, 0)
                textNode.addChildNode(reminderNode)
            }

            return textNode
        }

        /// Create a visual indicator for expiration warnings
        private func createExpirationWarningIndicator(for medication: Medication) -> SCNNode {
            let sphere = SCNSphere(radius: 0.8)

            // Choose color based on expiration status
            let warningColor = medication.warningColor
            let material = SCNMaterial()
            material.diffuse.contents = warningColor
            material.lightingModel = .constant
            sphere.materials = [material]

            let node = SCNNode(geometry: sphere)

            // Add pulsing animation for attention
            let scaleUp = SCNAction.scale(to: 1.2, duration: 0.5)
            let scaleDown = SCNAction.scale(to: 1.0, duration: 0.5)
            let pulse = SCNAction.sequence([scaleUp, scaleDown])
            let repeatPulse = SCNAction.repeatForever(pulse)
            node.runAction(repeatPulse)

            return node
        }

        /// Create a visual indicator for active reminders (bell icon)
        private func createReminderIndicator() -> SCNNode {
            // Create a simplified bell shape using cylinders and a sphere
            let node = SCNNode()

            // Bell body (cone-like cylinder)
            let bellBody = SCNCylinder(radius: 0.6, height: 1.0)
            let bellMaterial = SCNMaterial()
            bellMaterial.diffuse.contents = UIColor.systemBlue
            bellMaterial.lightingModel = .constant
            bellBody.materials = [bellMaterial]

            let bellBodyNode = SCNNode(geometry: bellBody)
            bellBodyNode.position = SCNVector3(0, 0, 0)

            // Bell clapper (small sphere at bottom)
            let clapper = SCNSphere(radius: 0.2)
            clapper.materials = [bellMaterial]

            let clapperNode = SCNNode(geometry: clapper)
            clapperNode.position = SCNVector3(0, -0.6, 0)

            // Badge (small red sphere for notification badge)
            let badge = SCNSphere(radius: 0.3)
            let badgeMaterial = SCNMaterial()
            badgeMaterial.diffuse.contents = UIColor.systemRed
            badgeMaterial.lightingModel = .constant
            badge.materials = [badgeMaterial]

            let badgeNode = SCNNode(geometry: badge)
            badgeNode.position = SCNVector3(0.5, 0.5, 0)

            // Assemble bell
            node.addChildNode(bellBodyNode)
            node.addChildNode(clapperNode)
            node.addChildNode(badgeNode)

            // Add subtle ringing animation
            let rotateLeft = SCNAction.rotateBy(x: 0, y: 0, z: CGFloat.pi / 16, duration: 0.1)
            let rotateRight = SCNAction.rotateBy(x: 0, y: 0, z: -CGFloat.pi / 8, duration: 0.2)
            let rotateBack = SCNAction.rotateBy(x: 0, y: 0, z: CGFloat.pi / 16, duration: 0.1)
            let wait = SCNAction.wait(duration: 2.0)
            let ring = SCNAction.sequence([rotateLeft, rotateRight, rotateBack, wait])
            let repeatRing = SCNAction.repeatForever(ring)
            node.runAction(repeatRing)

            return node
        }

        /// Create procedural box geometry using vertices and indices
        /// This allows for future friction-fit geometry generation
        private func createProceduralBoxGeometry(width: Float, height: Float, depth: Float) -> SCNGeometry {
            let w = width / 2.0
            let h = height / 2.0
            let d = depth / 2.0

            // Define 8 vertices of a box (in local space, centered at origin)
            let vertices: [SCNVector3] = [
                // Front face
                SCNVector3(-w, -h, d),  // 0: bottom-left-front
                SCNVector3(w, -h, d),   // 1: bottom-right-front
                SCNVector3(w, h, d),    // 2: top-right-front
                SCNVector3(-w, h, d),   // 3: top-left-front
                // Back face
                SCNVector3(-w, -h, -d), // 4: bottom-left-back
                SCNVector3(w, -h, -d),  // 5: bottom-right-back
                SCNVector3(w, h, -d),   // 6: top-right-back
                SCNVector3(-w, h, -d)   // 7: top-left-back
            ]

            // Define indices for 6 faces (2 triangles per face, counter-clockwise)
            let indices: [UInt16] = [
                // Front face
                0, 1, 2, 0, 2, 3,
                // Right face
                1, 5, 6, 1, 6, 2,
                // Back face
                5, 4, 7, 5, 7, 6,
                // Left face
                4, 0, 3, 4, 3, 7,
                // Top face
                3, 2, 6, 3, 6, 7,
                // Bottom face
                4, 5, 1, 4, 1, 0
            ]

            // Create vertex data
            let vertexData = Data(bytes: vertices, count: vertices.count * MemoryLayout<SCNVector3>.stride)
            let vertexSource = SCNGeometrySource(
                data: vertexData,
                semantic: .vertex,
                vectorCount: vertices.count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<SCNVector3>.stride
            )

            // Create normal data (computed per-face)
            var normals: [SCNVector3] = []
            for _ in 0..<vertices.count {
                normals.append(SCNVector3(0, 0, 0))
            }

            // Calculate normals for each triangle
            for i in stride(from: 0, to: indices.count, by: 3) {
                let i0 = Int(indices[i])
                let i1 = Int(indices[i + 1])
                let i2 = Int(indices[i + 2])

                let v0 = vertices[i0]
                let v1 = vertices[i1]
                let v2 = vertices[i2]

                // Calculate face normal
                let edge1 = SCNVector3(v1.x - v0.x, v1.y - v0.y, v1.z - v0.z)
                let edge2 = SCNVector3(v2.x - v0.x, v2.y - v0.y, v2.z - v0.z)

                let normal = SCNVector3(
                    edge1.y * edge2.z - edge1.z * edge2.y,
                    edge1.z * edge2.x - edge1.x * edge2.z,
                    edge1.x * edge2.y - edge1.y * edge2.x
                )

                // Accumulate normals for each vertex
                normals[i0] = SCNVector3(normals[i0].x + normal.x, normals[i0].y + normal.y, normals[i0].z + normal.z)
                normals[i1] = SCNVector3(normals[i1].x + normal.x, normals[i1].y + normal.y, normals[i1].z + normal.z)
                normals[i2] = SCNVector3(normals[i2].x + normal.x, normals[i2].y + normal.y, normals[i2].z + normal.z)
            }

            // Normalize accumulated normals
            normals = normals.map { normal in
                let length = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
                return length > 0 ? SCNVector3(normal.x / length, normal.y / length, normal.z / length) : normal
            }

            let normalData = Data(bytes: normals, count: normals.count * MemoryLayout<SCNVector3>.stride)
            let normalSource = SCNGeometrySource(
                data: normalData,
                semantic: .normal,
                vectorCount: normals.count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<SCNVector3>.stride
            )

            // Create element (indices)
            let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt16>.stride)
            let element = SCNGeometryElement(
                data: indexData,
                primitiveType: .triangles,
                primitiveCount: indices.count / 3,
                bytesPerIndex: MemoryLayout<UInt16>.stride
            )

            // Create geometry
            return SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        }

        /// Update an existing compartment node
        private func updateCompartmentNode(_ node: SCNNode, with compartment: Compartment) {
            // Update position
            node.position = SCNVector3(
                compartment.positionX,
                compartment.positionY,
                compartment.positionZ
            )

            // Update geometry if dimensions changed
            if let box = node.geometry as? SCNBox {
                if Float(box.width) != compartment.width ||
                   Float(box.height) != compartment.height ||
                   Float(box.length) != compartment.depth {
                    let newBox = SCNBox(
                        width: CGFloat(compartment.width),
                        height: CGFloat(compartment.height),
                        length: CGFloat(compartment.depth),
                        chamferRadius: 0.5
                    )
                    let material = Scene3DService.shared.createMaterial(colorHex: compartment.colorHex ?? "#CCCCCC")
                    newBox.materials = [material]
                    node.geometry = newBox
                }
            }
        }

        /// Update selection highlights for all compartments
        private func updateSelectionHighlights() {
            guard let selectedID = parent.selectedCompartment?.id else {
                // Clear all highlights
                compartmentNodes.values.forEach { clearHighlight(from: $0) }
                return
            }

            // Highlight selected, clear others
            for (id, node) in compartmentNodes {
                if id == selectedID {
                    applyHighlight(to: node)
                } else {
                    clearHighlight(from: node)
                }
            }
        }

        /// Apply selection highlight to a node
        private func applyHighlight(to node: SCNNode) {
            if node.geometry != nil {
                // Add wireframe overlay
                let outlineMaterial = SCNMaterial()
                outlineMaterial.diffuse.contents = UIColor.systemBlue
                outlineMaterial.fillMode = .lines
                outlineMaterial.isDoubleSided = true

                // Store original materials if not already stored
                if node.geometry?.materials.count == 1 {
                    node.geometry?.materials.append(outlineMaterial)
                }
            }
        }

        /// Clear selection highlight from a node
        private func clearHighlight(from node: SCNNode) {
            // Remove wireframe overlay if present
            if node.geometry?.materials.count ?? 0 > 1 {
                node.geometry?.materials = Array(node.geometry?.materials.prefix(1) ?? [])
            }
        }

        // MARK: - Gesture Handlers

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let sceneView = sceneView,
                  let cameraNode = sceneView.scene?.rootNode.childNode(withName: "camera", recursively: true) ?? sceneView.scene?.rootNode.childNodes.first(where: { $0.camera != nil }) else {
                return
            }

            if gesture.state == .changed {
                // Adjust camera distance based on pinch scale
                let scaleFactor = Float(gesture.scale)
                cameraDistance = max(10.0, min(100.0, cameraDistance / scaleFactor))

                // Update camera position
                updateCameraPosition(cameraNode)

                gesture.scale = 1.0
            }
        }

        @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
            guard let sceneView = sceneView,
                  let cameraNode = sceneView.scene?.rootNode.childNode(withName: "camera", recursively: true) ?? sceneView.scene?.rootNode.childNodes.first(where: { $0.camera != nil }) else {
                return
            }

            if gesture.state == .changed {
                // Rotate camera around Y axis
                cameraAngleY += Float(gesture.rotation)
                updateCameraPosition(cameraNode)
                gesture.rotation = 0
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let sceneView = sceneView,
                  let cameraNode = sceneView.scene?.rootNode.childNode(withName: "camera", recursively: true) ?? sceneView.scene?.rootNode.childNodes.first(where: { $0.camera != nil }) else {
                return
            }

            let translation = gesture.translation(in: sceneView)

            if gesture.state == .changed {
                // Update camera angles based on pan
                cameraAngleX -= Float(translation.y) * 0.01
                cameraAngleY += Float(translation.x) * 0.01

                // Clamp X angle to prevent flipping
                cameraAngleX = max(-Float.pi / 2, min(Float.pi / 2, cameraAngleX))

                updateCameraPosition(cameraNode)
                gesture.setTranslation(.zero, in: sceneView)
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let sceneView = sceneView else { return }

            let location = gesture.location(in: sceneView)
            let hitResults = sceneView.hitTest(location, options: [:])

            if let firstHit = hitResults.first,
               let nodeName = firstHit.node.name,
               let uuid = UUID(uuidString: nodeName) {
                // Find compartment with matching ID
                if let organizer = parent.organizer {
                    let matchingCompartment = organizer.compartmentsArray.first { $0.id == uuid }
                    parent.selectedCompartment = matchingCompartment
                }
            } else {
                // Tapped on empty space - deselect
                parent.selectedCompartment = nil
            }
        }

        /// Update camera position based on current angles and distance
        private func updateCameraPosition(_ cameraNode: SCNNode) {
            let x = cameraDistance * cos(cameraAngleX) * sin(cameraAngleY)
            let y = cameraDistance * sin(cameraAngleX)
            let z = cameraDistance * cos(cameraAngleX) * cos(cameraAngleY)

            cameraNode.position = SCNVector3(x, y, z)
            cameraNode.look(at: SCNVector3(0, 0, 0))
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension Scene3DView.Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow pinch, rotation, and pan gestures to work simultaneously
        return true
    }
}
