//
//  ComponentLibraryView.swift
//  Peppermint
//
//  Created by Claude on 2026-03-11.
//

import SwiftUI

/// View displaying preset compartments from PresetCompartments.json as draggable buttons
struct ComponentLibraryView: View {

    // MARK: - Properties

    @ObservedObject var viewModel: OrganizerViewModel

    // Preset compartment sizes (in mm, multiples of 5mm)
    private let presetCompartments: [CompartmentPreset] = [
        CompartmentPreset(name: "Small", width: 10, height: 10, depth: 10, icon: "square"),
        CompartmentPreset(name: "Medium", width: 15, height: 10, depth: 10, icon: "rectangle"),
        CompartmentPreset(name: "Large", width: 20, height: 15, depth: 15, icon: "square.grid.2x2"),
        CompartmentPreset(name: "Tall", width: 10, height: 20, depth: 10, icon: "rectangle.portrait"),
        CompartmentPreset(name: "Wide", width: 25, height: 10, depth: 10, icon: "rectangle.landscape")
    ]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Component Library")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(presetCompartments) { preset in
                        CompartmentButton(preset: preset) {
                            addCompartmentFromPreset(preset)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Actions

    /// Add a compartment from a preset to the organizer
    private func addCompartmentFromPreset(_ preset: CompartmentPreset) {
        // Find a suitable position for the new compartment
        let position = findAvailablePosition(for: preset)

        viewModel.addCompartment(
            width: preset.width,
            height: preset.height,
            depth: preset.depth,
            position: position,
            colorHex: preset.colorHex
        )
    }

    /// Find an available position that doesn't overlap with existing compartments
    private func findAvailablePosition(for preset: CompartmentPreset) -> SIMD3<Float> {
        // Start at origin and search for empty space
        var testPosition = SIMD3<Float>(0, 0, 0)
        let stepSize: Float = 5.0

        // Simple grid search (can be optimized later)
        for x in stride(from: Float(-25), to: Float(30), by: stepSize) {
            for z in stride(from: Float(-25), to: Float(30), by: stepSize) {
                testPosition = SIMD3<Float>(x, 0, z)

                if !wouldOverlap(position: testPosition, preset: preset) {
                    return testPosition
                }
            }
        }

        // If no position found, return origin (collision detection will warn user)
        return SIMD3<Float>(0, 0, 0)
    }

    /// Check if a position would cause overlap with existing compartments
    private func wouldOverlap(position: SIMD3<Float>, preset: CompartmentPreset) -> Bool {
        let testBounds = CompartmentBounds(
            minX: position.x,
            maxX: position.x + preset.width,
            minY: position.y,
            maxY: position.y + preset.height,
            minZ: position.z,
            maxZ: position.z + preset.depth
        )

        for compartment in viewModel.compartments {
            let bounds = CompartmentBounds(
                minX: compartment.positionX,
                maxX: compartment.positionX + compartment.width,
                minY: compartment.positionY,
                maxY: compartment.positionY + compartment.height,
                minZ: compartment.positionZ,
                maxZ: compartment.positionZ + compartment.depth
            )

            if testBounds.intersects(bounds) {
                return true
            }
        }

        return false
    }
}

// MARK: - Supporting Views

/// Button representing a compartment preset
struct CompartmentButton: View {
    let preset: CompartmentPreset
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color(hex: preset.colorHex))
                    .cornerRadius(8)

                Text(preset.name)
                    .font(.caption)
                    .foregroundColor(.primary)

                Text("\(Int(preset.width))×\(Int(preset.height))×\(Int(preset.depth))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Types

/// Preset compartment configuration
struct CompartmentPreset: Identifiable {
    let id = UUID()
    let name: String
    let width: Float
    let height: Float
    let depth: Float
    let icon: String
    var colorHex: String = "#8E8E93"  // Default gray
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
