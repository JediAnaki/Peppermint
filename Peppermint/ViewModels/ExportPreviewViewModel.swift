//
//  ExportPreviewViewModel.swift
//  Peppermint
//
//  Created for Feature: OpenSCAD-Based STL Export with Cloud Sync
//  Phase 3 - User Story 1: Business logic for interactive 3D preview export
//

import Foundation
import SceneKit
import UIKit

// MARK: - Export Preview ViewModel

@MainActor
final class ExportPreviewViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isShowingPreview = false
    @Published var isLoading = false
    @Published var previewNode: SCNNode?
    @Published var error: String?

    // MARK: - Dependencies

    private let openSCADAPI = OpenSCADAPIService.shared
    private let cacheService: PreviewCacheService
    private let persistenceService: DataPersistenceService

    // MARK: - State

    private var currentOrganizer: OrganizerDesign?

    // MARK: - Initialization

    init(persistenceService: DataPersistenceService = .shared) {
        self.persistenceService = persistenceService
        self.cacheService = PreviewCacheService(context: persistenceService.viewContext)
    }

    // MARK: - Public API

    /// Shows interactive 3D preview for organizer export
    ///
    /// **Flow**:
    /// 1. Show loading state
    /// 2. Try to load from cache (cache-first strategy)
    /// 3. If cache miss, request from OpenSCAD server
    /// 4. If server fails, fallback to local STL generation
    /// 5. Parse STL and create SceneKit preview
    /// 6. Present preview sheet
    ///
    /// - Parameter organizer: The organizer design to preview
    func showPreview(for organizer: OrganizerDesign) {
        currentOrganizer = organizer
        isShowingPreview = true
        isLoading = true
        error = nil
        previewNode = nil

        // Load STL asynchronously
        Task {
            await loadSTL(for: organizer, includePills: false)
        }
    }

    // MARK: - STL Loading (Cache → Server → Fallback)

    /// Loads STL with cache-first strategy, server request, and local fallback
    ///
    /// **Performance**: SC-002 target <2 seconds preview load time
    ///
    /// - Parameters:
    ///   - organizer: The organizer to generate STL for
    ///   - includePills: Whether to include pill visualization (future: US4)
    private func loadSTL(for organizer: OrganizerDesign, includePills: Bool) async {
        print("🔄 Loading STL preview for '\(organizer.name ?? "Unnamed")'...")

        do {
            // Step 1: Check cache first (instant if hit)
            if let cachedSTL = cacheService.getCachedSTL(for: organizer, includePills: includePills) {
                print("✅ Using cached STL")
                await loadPreviewFromSTL(cachedSTL, organizer: organizer)
                return
            }

            // Step 2: Request from OpenSCAD server
            print("📡 Requesting STL from OpenSCAD server...")
            let (stlData, triangleCount) = try await openSCADAPI.generateSTL(
                organizer: organizer,
                includePills: includePills
            )

            // Cache the result for future use
            cacheService.cacheSTL(stlData, for: organizer, includePills: includePills, triangleCount: triangleCount)

            // Load preview
            await loadPreviewFromSTL(stlData, organizer: organizer)

        } catch {
            // Step 3: Fallback to local generation on server failure
            print("⚠️ Server request failed: \(error.localizedDescription)")
            print("📦 Falling back to local STL generation...")
            await fallbackToLocalGeneration(organizer: organizer)
        }
    }

    /// Loads preview from STL binary data
    ///
    /// **Implementation**:
    /// 1. Parse binary STL using STLLoader
    /// 2. Create parent SCNNode to hold all compartment meshes
    /// 3. For each compartment, create colored geometry with 70% transparency
    /// 4. Combine into single preview node
    ///
    /// - Parameters:
    ///   - stlData: Binary STL file data
    ///   - organizer: The organizer (for compartment colors)
    private func loadPreviewFromSTL(_ stlData: Data, organizer: OrganizerDesign) async {
        do {
            // Parse STL into SceneKit geometry
            // Note: Server returns single merged STL, we apply compartment colors client-side
            let compartments = organizer.compartments as? Set<Compartment> ?? []
            let firstCompartment = compartments.first

            // Use first compartment color or default gray
            let color = firstCompartment?.uiColor ?? UIColor.systemGray

            // Load STL with 70% transparency (FR-005: semi-transparent preview)
            let node = try STLLoader.loadSTL(data: stlData, color: color, transparency: 0.7)

            // Update UI on main thread
            self.previewNode = node
            self.isLoading = false
            print("✅ Preview loaded successfully")

        } catch {
            self.error = "Failed to load preview: \(error.localizedDescription)"
            self.isLoading = false
            print("❌ Preview load failed: \(error)")
        }
    }

    /// Fallback to local STL generation when server unavailable
    ///
    /// **Offline-first compliance**: FR-006 (server fallback)
    ///
    /// Uses existing STLExporter.swift from feature 001-pill-organizer-3d
    ///
    /// - Parameter organizer: The organizer to generate STL for
    private func fallbackToLocalGeneration(organizer: OrganizerDesign) async {
        do {
            // Create temporary file for local STL export
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("stl")

            // Use existing STLExporter for local generation
            let _ = try STLExporter.export(organizer: organizer, to: tempURL)

            // Read generated STL
            let stlData = try Data(contentsOf: tempURL)

            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)

            // Load preview from local STL
            await loadPreviewFromSTL(stlData, organizer: organizer)

            // Show user notification about fallback
            self.error = "Using local preview (server unavailable)"
            print("✅ Fallback to local generation successful")

        } catch {
            self.error = "Failed to generate preview: \(error.localizedDescription)"
            self.isLoading = false
            print("❌ Local generation failed: \(error)")
        }
    }

    // MARK: - Export Confirmation

    /// Confirms export and generates final STL file for sharing
    ///
    /// **Export rules**:
    /// - Always generates STL with `includePills: false` (FR-019: clean export)
    /// - Uses server if available, local fallback otherwise
    /// - Shares via UIActivityViewController for AirDrop/Files/etc
    ///
    /// - Parameter organizer: The organizer to export
    func confirmExport(organizer: OrganizerDesign) {
        print("📤 Confirming export for '\(organizer.name ?? "Unnamed")'...")

        Task {
            do {
                // Generate final STL (always without pills)
                let (stlData, _) = try await openSCADAPI.generateSTL(
                    organizer: organizer,
                    includePills: false  // FR-019: pills excluded from export
                )

                // Create file for sharing
                let fileName = "\(organizer.name ?? "Organizer")_\(Date().ISO8601Format()).stl"
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(fileName)

                try stlData.write(to: tempURL)

                // Share via activity controller
                await shareFile(at: tempURL)

                print("✅ Export completed: \(fileName)")

            } catch {
                // Fallback to local export on server failure
                print("⚠️ Server export failed, using local fallback...")
                await exportLocally(organizer: organizer)
            }
        }
    }

    /// Shares STL file using UIActivityViewController
    private func shareFile(at url: URL) async {
        // Get key window for presenting activity controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ Failed to find root view controller for sharing")
            return
        }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        // Present activity controller
        rootViewController.present(activityVC, animated: true)
    }

    /// Exports STL locally using existing STLExporter
    private func exportLocally(organizer: OrganizerDesign) async {
        do {
            let fileName = "\(organizer.name ?? "Organizer")_\(Date().ISO8601Format()).stl"
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)

            let _ = try STLExporter.export(organizer: organizer, to: tempURL)

            await shareFile(at: tempURL)

            print("✅ Local export completed: \(fileName)")

        } catch {
            self.error = "Export failed: \(error.localizedDescription)"
            print("❌ Local export failed: \(error)")
        }
    }
}

// MARK: - Compartment Color Extension

private extension Compartment {
    /// Converts hex color string to UIColor
    var uiColor: UIColor {
        let hexString = colorHex ?? "#CCCCCC"
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0

        Scanner(string: hex).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
