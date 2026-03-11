//
//  CompartmentDetailSheet.swift
//  Peppermint
//
//  Created by Claude on 2026-03-11.
//

import SwiftUI

/// Sheet view for editing compartment medication details
struct CompartmentDetailSheet: View {

    // MARK: - Properties

    @ObservedObject var medicationViewModel: MedicationViewModel
    let compartment: Compartment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Form State

    @State private var medicationName: String = ""
    @State private var expirationDate: Date = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
    @State private var hasExpirationDate: Bool = false
    @State private var selectedCategory: String = ""
    @State private var notes: String = ""
    @State private var showingCategoryPicker: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            Form {
                // Medication Name Section
                Section(header: Text("Medication")) {
                    TextField("Medication Name", text: $medicationName)
                        .textInputAutocapitalization(.words)

                    // Category Selection
                    Button(action: { showingCategoryPicker = true }) {
                        HStack {
                            Text("Category")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(selectedCategory.isEmpty ? "None" : selectedCategory)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Expiration Date Section
                Section(header: Text("Expiration")) {
                    Toggle("Has Expiration Date", isOn: $hasExpirationDate)

                    if hasExpirationDate {
                        DatePicker("Expiration Date",
                                 selection: $expirationDate,
                                 displayedComponents: .date)

                        // Expiration warning
                        if let warning = expirationWarning {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(warning.color)
                                Text(warning.message)
                                    .font(.caption)
                                    .foregroundColor(warning.color)
                            }
                        }
                    }
                }

                // Notes Section
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                // Compartment Info Section
                Section(header: Text("Compartment Info")) {
                    HStack {
                        Text("Size")
                        Spacer()
                        Text("\(Int(compartment.width))×\(Int(compartment.height))×\(Int(compartment.depth)) mm")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Position")
                        Spacer()
                        Text("(\(Int(compartment.positionX)), \(Int(compartment.positionY)), \(Int(compartment.positionZ)))")
                            .foregroundColor(.secondary)
                    }
                }

                // Delete Medication Section (if exists)
                if compartment.medication != nil {
                    Section {
                        Button(role: .destructive, action: deleteMedication) {
                            HStack {
                                Spacer()
                                Label("Remove Medication", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Medication Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMedication()
                    }
                    .disabled(medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingCategoryPicker) {
                categoryPickerView
            }
            .onAppear {
                loadExistingMedication()
            }
        }
    }

    // MARK: - Category Picker

    private var categoryPickerView: some View {
        NavigationView {
            List {
                // Custom category input
                Section(header: Text("Custom Category")) {
                    TextField("Enter category name", text: $selectedCategory)
                        .textInputAutocapitalization(.words)
                }

                // Common categories
                Section(header: Text("Common Categories")) {
                    ForEach(MedicationViewModel.commonCategories, id: \.self) { category in
                        Button(action: {
                            selectedCategory = category
                            showingCategoryPicker = false
                        }) {
                            HStack {
                                Text(category)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedCategory == category {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }

                // Previously used categories
                if !medicationViewModel.categories.isEmpty {
                    Section(header: Text("Previously Used")) {
                        ForEach(medicationViewModel.categories, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                                showingCategoryPicker = false
                            }) {
                                HStack {
                                    Text(category)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedCategory == category {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingCategoryPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Expiration Warning

    private var expirationWarning: (message: String, color: Color)? {
        guard hasExpirationDate else { return nil }

        let calendar = Calendar.current
        let daysUntilExpiration = calendar.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0

        if daysUntilExpiration < 0 {
            return ("This medication is expired", .red)
        } else if daysUntilExpiration < 7 {
            return ("Expires in \(daysUntilExpiration) days", .orange)
        } else if daysUntilExpiration < 30 {
            return ("Expires in \(daysUntilExpiration) days", .yellow)
        }

        return nil
    }

    // MARK: - Actions

    private func loadExistingMedication() {
        if let medication = compartment.medication {
            medicationName = medication.name ?? ""
            selectedCategory = medication.category ?? ""
            notes = medication.notes ?? ""

            if let expDate = medication.expirationDate {
                hasExpirationDate = true
                expirationDate = expDate
            }
        }
    }

    private func saveMedication() {
        let trimmedName = medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        medicationViewModel.assignMedication(
            to: compartment,
            name: trimmedName,
            expirationDate: hasExpirationDate ? expirationDate : nil,
            category: selectedCategory.isEmpty ? nil : selectedCategory,
            notes: notes.isEmpty ? nil : notes
        )

        dismiss()
    }

    private func deleteMedication() {
        medicationViewModel.removeMedication(from: compartment)
        dismiss()
    }
}

// MARK: - Preview

struct CompartmentDetailSheet_Previews: PreviewProvider {
    static var previews: some View {
        let context = DataPersistenceService.preview.viewContext
        let organizer = OrganizerDesign(context: context)
        organizer.id = UUID()
        organizer.name = "Preview Organizer"

        let compartment = Compartment(context: context)
        compartment.id = UUID()
        compartment.width = 10
        compartment.height = 10
        compartment.depth = 10
        compartment.positionX = 0
        compartment.positionY = 0
        compartment.positionZ = 0
        compartment.colorHex = "#8E8E93"
        compartment.createdAt = Date()
        compartment.organizer = organizer

        return CompartmentDetailSheet(
            medicationViewModel: MedicationViewModel(persistenceService: DataPersistenceService.preview),
            compartment: compartment
        )
    }
}
