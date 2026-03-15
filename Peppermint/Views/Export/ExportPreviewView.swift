//
//  ExportPreviewView.swift
//  Peppermint
//
//  Created for Feature: OpenSCAD-Based STL Export with Cloud Sync
//  Phase 3 - User Story 1: Interactive 3D preview UI with SceneKit
//

import SwiftUI
import SceneKit

// MARK: - Export Preview View

struct ExportPreviewView: View {

    // MARK: - Properties

    @StateObject private var viewModel: ExportPreviewViewModel
    @Environment(\.dismiss) private var dismiss

    let organizer: OrganizerDesign

    // MARK: - Initialization

    init(organizer: OrganizerDesign) {
        self.organizer = organizer
        _viewModel = StateObject(wrappedValue: ExportPreviewViewModel())
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                // Content
                VStack(spacing: 0) {
                    // Preview or loading state
                    previewContent

                    // Gesture hint
                    gestureHintView
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .secondarySystemBackground))
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel button
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel preview")
                }

                // Export STL button
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export STL") {
                        viewModel.confirmExport(organizer: organizer)
                    }
                    .disabled(viewModel.previewNode == nil)
                    .accessibilityLabel("Export STL file")
                    .accessibilityHint("Saves the 3D model as an STL file for 3D printing")
                }
            }
        }
    }

    // MARK: - Preview Content

    @ViewBuilder
    private var previewContent: some View {
        if viewModel.isLoading {
            // Loading state
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Generating preview...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Generating 3D preview")

        } else if let error = viewModel.error {
            // Error state
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                Text(error)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Try Again") {
                    viewModel.showPreview(for: organizer)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Preview error: \(error)")

        } else if let previewNode = viewModel.previewNode {
            // Success - show SceneKit preview
            SceneKitPreviewView(rootNode: previewNode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(organizerAccessibilityLabel)
                .accessibilityHint("Use one finger to rotate, pinch to zoom, two fingers to pan")

        } else {
            // Initial/empty state
            VStack(spacing: 16) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("Preview not loaded")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Gesture Hint View

    private var gestureHintView: some View {
        HStack(spacing: 20) {
            Label("Rotate", systemImage: "hand.point.up.left")
            Label("Zoom", systemImage: "arrow.up.left.and.arrow.down.right")
            Label("Pan", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .accessibilityHidden(true)  // Redundant for VoiceOver (hint already in preview)
    }

    // MARK: - Accessibility

    private var organizerAccessibilityLabel: String {
        let compartmentCount = (organizer.compartments as? Set<Compartment>)?.count ?? 0
        return "3D preview of \(organizer.name ?? "organizer") with \(compartmentCount) compartments"
    }
}

// MARK: - SceneKit Preview View

struct SceneKitPreviewView: UIViewRepresentable {

    let rootNode: SCNNode

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()

        // Configure SceneKit view for interactive preview
        scnView.allowsCameraControl = true  // Enable pan/pinch/rotate gestures
        scnView.autoenablesDefaultLighting = true  // Automatic lighting
        scnView.backgroundColor = UIColor.systemBackground

        // Performance settings (SC-003: 60fps target)
        scnView.preferredFramesPerSecond = 60
        scnView.antialiasingMode = .multisampling4X  // Smooth edges

        // Create scene
        let scene = SCNScene()

        // Add root node (STL geometry)
        scene.rootNode.addChildNode(rootNode)

        // Setup camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 100)  // Position camera to view model
        scene.rootNode.addChildNode(cameraNode)

        // Assign scene
        scnView.scene = scene

        // Auto-frame the model in view
        scnView.pointOfView = cameraNode

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update if rootNode changes (future: pill toggle)
        if uiView.scene?.rootNode.childNodes.first !== rootNode {
            uiView.scene?.rootNode.childNodes.forEach { $0.removeFromParentNode() }
            uiView.scene?.rootNode.addChildNode(rootNode)
        }
    }
}

// MARK: - Preview Provider

#Preview {
    // Mock organizer for preview
    let context = DataPersistenceService.preview.container.viewContext
    let organizer = OrganizerDesign(context: context)
    organizer.id = UUID()
    organizer.name = "Sample Organizer"
    organizer.createdAt = Date()
    organizer.modifiedAt = Date()

    ExportPreviewView(organizer: organizer)
}
