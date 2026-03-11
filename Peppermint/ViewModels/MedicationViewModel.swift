//
//  MedicationViewModel.swift
//  Peppermint
//
//  Created by Claude on 2026-03-11.
//

import Foundation
import SwiftUI
import Combine
import CoreData

/// ViewModel managing medication assignment and categorization
@MainActor
class MedicationViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Currently selected medication for editing
    @Published var selectedMedication: Medication?

    /// Array of unique medication categories from database
    @Published var categories: [String] = []

    /// Error message to display to user
    @Published var errorMessage: String?

    /// Loading state for async operations
    @Published var isLoading: Bool = false

    // MARK: - Private Properties

    private let persistenceService: DataPersistenceService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(persistenceService: DataPersistenceService = DataPersistenceService.shared) {
        self.persistenceService = persistenceService
        loadCategories()
    }

    // MARK: - Public Methods

    /// Create or update medication for a compartment
    /// - Parameters:
    ///   - compartment: The compartment to assign medication to
    ///   - name: Medication name
    ///   - expirationDate: Optional expiration date
    ///   - category: Optional category (e.g., "Pain Relief", "Vitamins")
    ///   - notes: Optional notes about dosage/side effects
    func assignMedication(to compartment: Compartment,
                         name: String,
                         expirationDate: Date?,
                         category: String?,
                         notes: String?) {
        if let existingMedication = compartment.medication {
            // Update existing medication
            existingMedication.name = name
            existingMedication.expirationDate = expirationDate
            existingMedication.category = category
            existingMedication.notes = notes
            existingMedication.modifiedAt = Date()
        } else {
            // Create new medication
            let medication = Medication(context: persistenceService.viewContext)
            medication.id = UUID()
            medication.name = name
            medication.expirationDate = expirationDate
            medication.category = category
            medication.notes = notes
            medication.createdAt = Date()
            medication.modifiedAt = Date()
            medication.compartment = compartment
        }

        do {
            try persistenceService.viewContext.save()
            // Reload categories in case new one was added
            loadCategories()
        } catch {
            errorMessage = "Failed to assign medication: \(error.localizedDescription)"
        }
    }

    /// Remove medication from a compartment
    /// - Parameter compartment: The compartment to remove medication from
    func removeMedication(from compartment: Compartment) {
        guard let medication = compartment.medication else { return }

        persistenceService.viewContext.delete(medication)

        do {
            try persistenceService.viewContext.save()
        } catch {
            errorMessage = "Failed to remove medication: \(error.localizedDescription)"
        }
    }

    /// Load all unique medication categories from database
    func loadCategories() {
        let fetchRequest: NSFetchRequest<Medication> = Medication.fetchRequest()
        fetchRequest.propertiesToFetch = ["category"]
        fetchRequest.returnsDistinctResults = true

        do {
            let medications = try persistenceService.viewContext.fetch(fetchRequest)
            let uniqueCategories = Set(medications.compactMap { $0.category })
            self.categories = Array(uniqueCategories).sorted()
        } catch {
            print("Error loading categories: \(error)")
            self.categories = []
        }
    }

    /// Get suggested categories based on partial input (autocomplete)
    /// - Parameter input: Partial category name
    /// - Returns: Array of matching categories
    func suggestCategories(for input: String) -> [String] {
        guard !input.isEmpty else { return categories }

        return categories.filter { category in
            category.localizedCaseInsensitiveContains(input)
        }
    }

    /// Select a medication for editing
    /// - Parameter medication: The medication to select
    func selectMedication(_ medication: Medication?) {
        self.selectedMedication = medication
    }
}

// MARK: - Medication Category Presets

extension MedicationViewModel {
    /// Common medication categories for quick selection
    static let commonCategories = [
        "Pain Relief",
        "Vitamins",
        "Antibiotics",
        "Antihistamines",
        "Blood Pressure",
        "Diabetes",
        "Heart Health",
        "Digestive Health",
        "Mental Health",
        "Sleep Aid",
        "Cold & Flu",
        "Allergy",
        "Supplements",
        "Prescription",
        "Over-the-Counter"
    ]
}
