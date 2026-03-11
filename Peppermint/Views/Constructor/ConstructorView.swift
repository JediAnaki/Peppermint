//
//  ConstructorView.swift
//  Peppermint
//
//  Created by Claude on 2026-03-11.
//

import SwiftUI
import SceneKit

/// Main constructor view combining 3D scene and component library
struct ConstructorView: View {

    // MARK: - Properties

    @ObservedObject var organizer: OrganizerDesign
    @Environment(\.managedObjectContext) private var viewContext

    @StateObject private var viewModel = OrganizerViewModel()
    @StateObject private var medicationViewModel = MedicationViewModel()
    @State private var selectedCompartment: Compartment?
    @State private var sceneViewRef: SCNView?
    @State private var showingDeleteConfirmation = false
    @State private var showingMedicationSheet = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 3D Scene View
            Scene3DView(
                organizer: $viewModel.currentOrganizer,
                selectedCompartment: $selectedCompartment,
                sceneViewRef: $sceneViewRef
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Component Library
            ComponentLibraryView(viewModel: viewModel)
                .frame(height: 120)

            // Bottom toolbar
            bottomToolbar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("Organizer Name", text: Binding(
                    get: { organizer.name ?? "" },
                    set: { organizer.name = $0 }
                ))
                .font(.headline)
                .multilineTextAlignment(.center)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: saveOrganizer) {
                    Image(systemName: "checkmark")
                }
            }
        }
        .onAppear {
            viewModel.loadOrganizer(organizer)
        }
        .alert("Delete Compartment", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let compartment = selectedCompartment {
                    deleteSelectedCompartment(compartment)
                }
            }
        } message: {
            Text("Are you sure you want to delete this compartment?")
        }
        .sheet(isPresented: $showingMedicationSheet) {
            if let compartment = selectedCompartment {
                CompartmentDetailSheet(
                    medicationViewModel: medicationViewModel,
                    compartment: compartment
                )
            }
        }
        .onChange(of: selectedCompartment) { _, newValue in
            // Auto-open medication sheet when compartment is tapped
            if newValue != nil {
                showingMedicationSheet = true
            }
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 20) {
            // Delete button (only show when compartment is selected)
            if selectedCompartment != nil {
                Button(action: { showingDeleteConfirmation = true }) {
                    Label("Delete", systemImage: "trash")
                        .foregroundColor(.red)
                }

                Button(action: { showingMedicationSheet = true }) {
                    Label("Edit", systemImage: "pills")
                        .foregroundColor(.accentColor)
                }
            }

            Spacer()

            // Compartment count
            Label("\(viewModel.compartments.count) compartments", systemImage: "square.grid.2x2")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Actions

    private func saveOrganizer() {
        if let sceneView = sceneViewRef {
            viewModel.saveOrganizerWithThumbnail(from: sceneView)
        } else {
            viewModel.saveOrganizer()
        }
    }

    private func deleteSelectedCompartment(_ compartment: Compartment) {
        withAnimation {
            viewModel.removeCompartment(compartment)
            selectedCompartment = nil
        }
    }
}

// MARK: - Preview

struct ConstructorView_Previews: PreviewProvider {
    static var previews: some View {
        let context = DataPersistenceService.preview.viewContext
        let organizer = OrganizerDesign(context: context)
        organizer.id = UUID()
        organizer.name = "Preview Organizer"
        organizer.createdAt = Date()
        organizer.modifiedAt = Date()

        return NavigationView {
            ConstructorView(organizer: organizer)
                .environment(\.managedObjectContext, context)
        }
    }
}
