//
//  OrganizerLibraryView.swift
//  Peppermint
//
//  Created by Claude on 2026-03-11.
//

import SwiftUI
import CoreData

/// View displaying saved organizers as a grid of thumbnails
struct OrganizerLibraryView: View {

    // MARK: - Environment

    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Fetch Request

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OrganizerDesign.modifiedAt, ascending: false)],
        animation: .default)
    private var organizers: FetchedResults<OrganizerDesign>

    // MARK: - State

    @State private var showingNewOrganizerSheet = false
    @State private var newOrganizerName = ""
    @State private var selectedOrganizer: OrganizerDesign?
    @State private var showingDeleteConfirmation = false
    @State private var organizerToDelete: OrganizerDesign?
    @State private var filterCategory: String?
    @State private var filterColor: String?
    @State private var showingFilterMenu = false

    @StateObject private var viewModel = OrganizerViewModel()
    @StateObject private var medicationViewModel = MedicationViewModel()

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                if organizers.isEmpty {
                    emptyStateView
                } else {
                    libraryGridView
                }
            }
            .navigationTitle("My Organizers")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingFilterMenu = true }) {
                        Image(systemName: filterCategory != nil || filterColor != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewOrganizerSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog("Filter Organizers", isPresented: $showingFilterMenu) {
                Button("By Category") {
                    // Show category picker
                }
                Button("By Color") {
                    // Show color picker
                }
                if filterCategory != nil || filterColor != nil {
                    Button("Clear Filters", role: .destructive) {
                        filterCategory = nil
                        filterColor = nil
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingNewOrganizerSheet) {
                newOrganizerSheet
            }
            .alert("Delete Organizer", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    organizerToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let organizer = organizerToDelete {
                        deleteOrganizer(organizer)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this organizer? This action cannot be undone.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No organizers yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create your first pill organizer to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { showingNewOrganizerSheet = true }) {
                Label("Create New Organizer", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }

    // MARK: - Library Grid

    private var libraryGridView: some View {
        ScrollView {
            // Active filters display
            if filterCategory != nil || filterColor != nil {
                HStack {
                    if let category = filterCategory {
                        FilterChip(label: "Category: \(category)") {
                            filterCategory = nil
                        }
                    }
                    if let color = filterColor {
                        FilterChip(label: "Color: \(color)") {
                            filterColor = nil
                        }
                    }
                }
                .padding(.horizontal)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredOrganizers) { organizer in
                    NavigationLink(destination: constructorView(for: organizer)) {
                        OrganizerThumbnailView(organizer: organizer)
                            .contextMenu {
                                Button(action: { renameOrganizer(organizer) }) {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(action: { duplicateOrganizer(organizer) }) {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }
                                Divider()
                                Button(role: .destructive, action: {
                                    organizerToDelete = organizer
                                    showingDeleteConfirmation = true
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    // MARK: - New Organizer Sheet

    private var newOrganizerSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Organizer Name")) {
                    TextField("Enter name", text: $newOrganizerName)
                }
            }
            .navigationTitle("New Organizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingNewOrganizerSheet = false
                        newOrganizerName = ""
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createNewOrganizer()
                    }
                    .disabled(newOrganizerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Constructor View

    private func constructorView(for organizer: OrganizerDesign) -> some View {
        ConstructorView(organizer: organizer)
            .environment(\.managedObjectContext, viewContext)
    }

    // MARK: - Filtered Organizers

    private var filteredOrganizers: [OrganizerDesign] {
        var filtered = Array(organizers)

        // Filter by category
        if let category = filterCategory {
            filtered = filtered.filter { organizer in
                guard let compartments = organizer.compartments as? Set<Compartment> else { return false }
                return compartments.contains { compartment in
                    compartment.medication?.category == category
                }
            }
        }

        // Filter by color
        if let color = filterColor {
            filtered = filtered.filter { organizer in
                guard let compartments = organizer.compartments as? Set<Compartment> else { return false }
                return compartments.contains { compartment in
                    compartment.colorHex == color
                }
            }
        }

        return filtered
    }

    // MARK: - Actions

    private func createNewOrganizer() {
        let organizer = OrganizerDesign(context: viewContext)
        organizer.id = UUID()
        organizer.name = newOrganizerName.trimmingCharacters(in: .whitespacesAndNewlines)
        organizer.createdAt = Date()
        organizer.modifiedAt = Date()

        do {
            try viewContext.save()
            showingNewOrganizerSheet = false
            newOrganizerName = ""
        } catch {
            print("Error creating organizer: \(error)")
        }
    }

    private func deleteOrganizer(_ organizer: OrganizerDesign) {
        viewContext.delete(organizer)

        do {
            try viewContext.save()
        } catch {
            print("Error deleting organizer: \(error)")
        }

        organizerToDelete = nil
    }

    private func renameOrganizer(_ organizer: OrganizerDesign) {
        // TODO: Implement rename functionality with alert
        print("Rename organizer: \(organizer.name ?? "")")
    }

    private func duplicateOrganizer(_ organizer: OrganizerDesign) {
        let duplicate = OrganizerDesign(context: viewContext)
        duplicate.id = UUID()
        duplicate.name = "\(organizer.name ?? "Organizer") Copy"
        duplicate.createdAt = Date()
        duplicate.modifiedAt = Date()
        duplicate.thumbnailData = organizer.thumbnailData

        // Duplicate all compartments
        if let compartments = organizer.compartments as? Set<Compartment> {
            for compartment in compartments {
                let newCompartment = Compartment(context: viewContext)
                newCompartment.id = UUID()
                newCompartment.width = compartment.width
                newCompartment.height = compartment.height
                newCompartment.depth = compartment.depth
                newCompartment.positionX = compartment.positionX
                newCompartment.positionY = compartment.positionY
                newCompartment.positionZ = compartment.positionZ
                newCompartment.colorHex = compartment.colorHex
                newCompartment.connectorMetadata = compartment.connectorMetadata
                newCompartment.createdAt = Date()
                newCompartment.organizer = duplicate

                // Duplicate medication if exists
                if let medication = compartment.medication {
                    let newMedication = Medication(context: viewContext)
                    newMedication.id = UUID()
                    newMedication.name = medication.name
                    newMedication.expirationDate = medication.expirationDate
                    newMedication.category = medication.category
                    newMedication.notes = medication.notes
                    newMedication.createdAt = Date()
                    newMedication.modifiedAt = Date()
                    newMedication.compartment = newCompartment
                }
            }
        }

        do {
            try viewContext.save()
        } catch {
            print("Error duplicating organizer: \(error)")
        }
    }
}

// MARK: - Thumbnail View

struct OrganizerThumbnailView: View {
    let organizer: OrganizerDesign

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail image
            ZStack {
                if let thumbnailData = organizer.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 150)
                        .clipped()
                } else {
                    // Placeholder if no thumbnail
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 150)
                        .overlay(
                            Image(systemName: "cube.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                }
            }
            .cornerRadius(8)

            // Organizer name
            Text(organizer.name ?? "Untitled")
                .font(.headline)
                .lineLimit(1)

            // Metadata
            HStack {
                Label("\(organizer.compartmentCount)", systemImage: "square.grid.2x2")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let modifiedAt = organizer.modifiedAt {
                    Text(modifiedAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.2))
        .cornerRadius(16)
    }
}

// MARK: - Preview

struct OrganizerLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        OrganizerLibraryView()
            .environment(\.managedObjectContext, DataPersistenceService.preview.viewContext)
    }
}
