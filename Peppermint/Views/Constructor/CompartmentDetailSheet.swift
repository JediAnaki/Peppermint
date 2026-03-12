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
    @StateObject private var reminderViewModel = ReminderViewModel()
    let compartment: Compartment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Form State

    @State private var medicationName: String = ""
    @State private var expirationDate: Date = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
    @State private var hasExpirationDate: Bool = false
    @State private var selectedCategory: String = ""
    @State private var notes: String = ""
    @State private var showingCategoryPicker: Bool = false

    // Reminder state
    @State private var showingAddReminder: Bool = false
    @State private var reminderFrequency: ReminderFrequency = .daily
    @State private var reminderTime: Date = Date()
    @State private var selectedDaysOfWeek: Set<Int> = []
    @State private var showingPermissionAlert: Bool = false

    enum ReminderFrequency: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case custom = "Custom"
    }

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

                // Reminders Section
                if compartment.medication != nil {
                    Section(header: Text("Reminders")) {
                        // Existing reminders
                        if reminderViewModel.schedules.isEmpty {
                            Text("No reminders set")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        } else {
                            ForEach(reminderViewModel.schedules, id: \.id) { schedule in
                                reminderRow(for: schedule)
                            }
                        }

                        // Add reminder button
                        Button(action: addReminderTapped) {
                            Label("Add Reminder", systemImage: "bell.badge.fill")
                        }
                    }
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
            .sheet(isPresented: $showingAddReminder) {
                addReminderView
            }
            .alert("Notification Permissions Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    reminderViewModel.openSettings()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable notification permissions in Settings to receive medication reminders.")
            }
            .onAppear {
                loadExistingMedication()
                if let medication = compartment.medication {
                    reminderViewModel.loadSchedules(for: medication)
                }
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

    // MARK: - Reminder Row

    @ViewBuilder
    private func reminderRow(for schedule: ReminderSchedule) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.frequency?.capitalized ?? "Unknown")
                    .font(.body)

                if let timesData = schedule.timesOfDay,
                   let times = try? JSONDecoder().decode([String].self, from: timesData) {
                    Text(times.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Show days of week for weekly reminders
                if schedule.frequency == "weekly",
                   let daysData = schedule.daysOfWeek,
                   let days = try? JSONDecoder().decode([Int].self, from: daysData) {
                    Text(formatDaysOfWeek(days))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Show next reminder time if enabled
                if schedule.enabled, let nextTime = calculateNextReminderTime(for: schedule) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("Next: \(nextTime, style: .relative)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { schedule.enabled },
                set: { _ in
                    Task {
                        await reminderViewModel.toggleSchedule(schedule)
                    }
                }
            ))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task {
                    await reminderViewModel.deleteSchedule(schedule)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Add Reminder View

    private var addReminderView: some View {
        NavigationView {
            Form {
                // Frequency selection
                Section(header: Text("Frequency")) {
                    Picker("Frequency", selection: $reminderFrequency) {
                        ForEach(ReminderFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.rawValue).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Time selection
                Section(header: Text("Time")) {
                    DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }

                // Days of week (for weekly)
                if reminderFrequency == .weekly {
                    Section(header: Text("Days of Week")) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            let dayName = Calendar.current.weekdaySymbols[dayIndex]
                            Toggle(dayName, isOn: Binding(
                                get: { selectedDaysOfWeek.contains(dayIndex) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedDaysOfWeek.insert(dayIndex)
                                    } else {
                                        selectedDaysOfWeek.remove(dayIndex)
                                    }
                                }
                            ))
                        }
                    }
                }

                // Custom dates (for custom)
                if reminderFrequency == .custom {
                    Section(header: Text("Custom Dates")) {
                        Text("Custom date selection coming soon")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingAddReminder = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveReminder()
                        }
                    }
                    .disabled(!canSaveReminder)
                }
            }
        }
    }

    private var canSaveReminder: Bool {
        if reminderFrequency == .weekly && selectedDaysOfWeek.isEmpty {
            return false
        }
        return true
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

    private func addReminderTapped() {
        // Reset form
        reminderFrequency = .daily
        reminderTime = Date()
        selectedDaysOfWeek = []

        // Check permissions first
        if reminderViewModel.authorizationStatus == .denied {
            showingPermissionAlert = true
        } else {
            showingAddReminder = true
        }
    }

    private func saveReminder() async {
        guard let medication = compartment.medication else { return }

        // Format time as HH:mm
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: reminderTime)

        var daysOfWeek: [Int]? = nil
        if reminderFrequency == .weekly {
            daysOfWeek = Array(selectedDaysOfWeek).sorted()
        }

        let success = await reminderViewModel.createSchedule(
            for: medication,
            frequency: reminderFrequency.rawValue.lowercased(),
            timesOfDay: [timeString],
            daysOfWeek: daysOfWeek,
            customDates: nil,
            soundName: nil
        )

        if success {
            showingAddReminder = false
        } else if reminderViewModel.authorizationStatus == .denied {
            showingAddReminder = false
            showingPermissionAlert = true
        }
    }

    private func formatDaysOfWeek(_ days: [Int]) -> String {
        let dayNames = days.sorted().map { Calendar.current.shortWeekdaySymbols[$0] }
        return dayNames.joined(separator: ", ")
    }

    private func calculateNextReminderTime(for schedule: ReminderSchedule) -> Date? {
        guard let timesData = schedule.timesOfDay,
              let times = try? JSONDecoder().decode([String].self, from: timesData),
              let firstTime = times.first else {
            return nil
        }

        let calendar = Calendar.current
        let now = Date()

        // Parse time string (HH:mm)
        let timeComponents = firstTime.split(separator: ":")
        guard timeComponents.count == 2,
              let hour = Int(timeComponents[0]),
              let minute = Int(timeComponents[1]) else {
            return nil
        }

        switch schedule.frequency {
        case "daily":
            // Calculate next occurrence today or tomorrow
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = hour
            components.minute = minute

            if let nextTime = calendar.date(from: components), nextTime > now {
                return nextTime
            } else {
                // Move to tomorrow
                return calendar.date(byAdding: .day, value: 1, to: calendar.date(from: components)!)
            }

        case "weekly":
            guard let daysData = schedule.daysOfWeek,
                  let days = try? JSONDecoder().decode([Int].self, from: daysData) else {
                return nil
            }

            // Find next occurrence on specified days
            for dayOffset in 0..<7 {
                guard let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                let weekday = calendar.component(.weekday, from: checkDate) - 1 // Convert to 0-based

                if days.contains(weekday) {
                    var components = calendar.dateComponents([.year, .month, .day], from: checkDate)
                    components.hour = hour
                    components.minute = minute

                    if let nextTime = calendar.date(from: components), nextTime > now {
                        return nextTime
                    }
                }
            }

        case "custom":
            guard let datesData = schedule.customDates,
                  let dateStrings = try? JSONDecoder().decode([String].self, from: datesData) else {
                return nil
            }

            let dates = dateStrings.compactMap { ISO8601DateFormatter().date(from: $0) }

            // Find next custom date
            for customDate in dates.sorted() {
                var components = calendar.dateComponents([.year, .month, .day], from: customDate)
                components.hour = hour
                components.minute = minute

                if let nextTime = calendar.date(from: components), nextTime > now {
                    return nextTime
                }
            }

        default:
            break
        }

        return nil
    }

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
