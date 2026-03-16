//
//  OrganizerDesign+Helpers.swift
//  Peppermint
//
//  Created for Feature: OpenSCAD-Based STL Export with Cloud Sync
//  Helper computed properties for OrganizerDesign entity
//

import Foundation

// MARK: - OrganizerDesign Computed Properties

extension OrganizerDesign {

    /// Returns the total number of compartments in this organizer
    ///
    /// - Returns: Count of compartments
    var compartmentCount: Int {
        let compartmentsSet = compartments as? Set<Compartment> ?? []
        return compartmentsSet.count
    }

    /// Checks if the organizer has any compartments with medications assigned
    ///
    /// - Returns: `true` if at least one compartment has a medication, `false` otherwise
    var hasActiveMedications: Bool {
        let compartmentsSet = compartments as? Set<Compartment> ?? []
        return compartmentsSet.contains { $0.medication != nil }
    }

    /// Checks if the organizer has any medications with pending (active) reminders
    ///
    /// - Returns: `true` if at least one medication has enabled reminder schedules, `false` otherwise
    var hasPendingReminders: Bool {
        let compartmentsSet = compartments as? Set<Compartment> ?? []

        for compartment in compartmentsSet {
            if let medication = compartment.medication {
                if medication.hasActiveReminders {
                    return true
                }
            }
        }

        return false
    }
}
