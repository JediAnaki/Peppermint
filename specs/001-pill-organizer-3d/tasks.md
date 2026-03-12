# Tasks: 3D Pill Organizer with 3D Printing

**Input**: Design documents from `/specs/001-pill-organizer-3d/`
**Prerequisites**: plan.md (complete), spec.md (complete), data-model.md (complete), research.md (complete), contracts/ (complete)

**Tests**: Not explicitly requested in specification - tests are OPTIONAL for this feature.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **iOS app**: `Peppermint/` at repository root (Xcode project structure)
- Paths shown assume standard iOS project layout

---

## Phase 1: Setup (Shared Infrastructure) ✅ COMPLETED

**Purpose**: Project initialization and basic iOS app structure

- [X] T001 Create Xcode iOS app project "Peppermint" with Swift 5.9+, iOS 16.0+ deployment target, SwiftUI lifecycle
- [X] T002 Configure Peppermint.xcodeproj build settings (Swift 5.9+, Metal rendering API enabled, code signing)
- [X] T003 [P] Create folder structure: Peppermint/App/, Peppermint/Models/, Peppermint/Views/, Peppermint/ViewModels/, Peppermint/Services/, Peppermint/Utilities/, Peppermint/Resources/
- [X] T004 [P] Add Assets.xcassets with app icon placeholder and semantic color sets for Dark Mode
- [X] T005 [P] Create Localizable.strings in Peppermint/Resources/ with English base localization
- [X] T006 [P] Add Info.plist with required keys: Privacy - Face ID Usage Description, Privacy - Notifications Usage Description
- [X] T007 [P] Create PresetCompartments.json in Peppermint/Resources/ with component library data (copy from specs/001-pill-organizer-3d/contracts/component-library-schema.json examples)

---

## Phase 2: Foundational (Blocking Prerequisites) ✅ COMPLETED

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T008 Create CoreData model PeppermintDataModel.xcdatamodeld in Peppermint/Models/ with 5 entities: OrganizerDesign, Compartment, Medication, ReminderSchedule, ExportHistory (per data-model.md)
- [X] T009 Configure CoreData encryption in PeppermintDataModel.xcdatamodeld (set NSPersistentStoreFileProtectionKey to FileProtectionType.complete)
- [X] T010 [P] Generate NSManagedObject subclasses for all 5 CoreData entities in Peppermint/Models/ with computed properties from data-model.md
- [X] T011 Create DataPersistenceService.swift in Peppermint/Services/ with CoreData stack setup, CRUD operations, viewContext property
- [X] T012 [P] Create SnapToGridCalculator.swift in Peppermint/Utilities/ with snap(_ value: Float) -> Float function (5mm grid snapping)
- [X] T013 [P] Create BiometricAuthManager.swift in Peppermint/Utilities/ with Face ID/Touch ID authentication wrapper using LocalAuthentication framework
- [X] T014 [P] Create AccessibilityHelper.swift in Peppermint/Utilities/ with VoiceOver label generators and accessibility trait helpers
- [X] T015 Create PeppermintApp.swift in Peppermint/App/ as SwiftUI app entry point with CoreData environment injection
- [X] T016 Create ContentView.swift in Peppermint/App/ as root view with tab navigation (Constructor tab, Library tab placeholders)
- [X] T017 [P] Add SF Symbols to Assets.xcassets: square (small compartment), rectangle (medium), square.grid.2x2 (large), bell.badge (reminder), square.and.arrow.up (export)

**Checkpoint**: ✅ Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Build Custom Pill Organizer (Priority: P1) 🎯 MVP ✅ COMPLETED

**Goal**: Users can design custom pill organizers by assembling modular compartments in an interactive 3D workspace, manipulate the 3D model with gestures, and save designs

**Independent Test**: Launch app → tap "Create New Organizer" → select compartment from library → drag into 3D workspace → compartment snaps to grid → pinch/rotate/pan 3D model at 60 fps → tap "Save" → organizer appears in library

### Implementation for User Story 1

- [X] T018 [P] [US1] Create OrganizerViewModel.swift in Peppermint/ViewModels/ with @Published properties for currentOrganizer, compartments array, ObservableObject conformance
- [X] T019 [P] [US1] Create Scene3DService.swift in Peppermint/Services/ with SceneKit scene setup, Metal rendering config, 60 fps target, camera positioning
- [X] T020 [P] [US1] Create FrictionFitGenerator.swift in Peppermint/Services/ with generateConnectorMetadata(for: Compartment, in: OrganizerDesign) -> ConnectorMetadata function (auto-assign tabs/grooves based on neighbors)
- [X] T021 [US1] Create Scene3DView.swift in Peppermint/Views/Constructor/ as UIViewRepresentable wrapper for SCNView with Metal backend, gesture recognizers (pinch, rotate, pan), 60 fps rendering
- [X] T022 [US1] Implement compartment procedural geometry generation in Scene3DView.swift using SCNGeometry(sources:elements:) with vertices/indices for boxes with 5mm multiples
- [X] T023 [US1] Add gesture handling to Scene3DView.swift: UIPinchGestureRecognizer for zoom, UIRotationGestureRecognizer for rotation, UIPanGestureRecognizer for pan, all simultaneous
- [X] T024 [US1] Create ComponentLibraryView.swift in Peppermint/Views/Constructor/ displaying preset compartments from PresetCompartments.json as draggable buttons with SF Symbol icons
- [X] T025 [US1] Implement drag-and-drop from ComponentLibraryView to Scene3DView with snap-to-grid positioning using SnapToGridCalculator
- [X] T026 [US1] Add compartment selection to Scene3DView.swift using SCNView.hitTest for touch detection, highlight selected compartment with outline
- [X] T027 [US1] Add delete functionality to Scene3DView.swift with trash button that removes selected compartment with fade-out SCNAction animation
- [X] T028 [US1] Implement save functionality in OrganizerViewModel.swift calling DataPersistenceService to persist OrganizerDesign with all compartments to CoreData
- [X] T029 [US1] Add collision detection in OrganizerViewModel.swift to prevent overlapping compartments using bounding box intersection checks before adding to scene
- [X] T030 [US1] Create OrganizerLibraryView.swift in Peppermint/Views/Library/ displaying saved organizers as grid of thumbnails with 3D snapshot images and names
- [X] T031 [US1] Generate thumbnail snapshots in OrganizerViewModel.swift using SCNView.snapshot() when saving organizer, store as Data in OrganizerDesign.thumbnailData

**Checkpoint**: ✅ User Story 1 is now fully functional and testable independently - users can build, manipulate, and save custom 3D pill organizers

---

## Phase 4: User Story 2 - Assign Medications to Compartments (Priority: P2) ✅ COMPLETED

**Goal**: Users can assign medication information (name, expiration date, category, color) to compartments, see medication labels in 3D view without clicking, and filter by category/color

**Independent Test**: Open saved organizer → tap compartment → enter "Aspirin", expiration date, category "Pain Relief", color blue → medication label appears on compartment in 3D view → expiration warning shows if <30 days → filter library by category

### Implementation for User Story 2

- [X] T032 [P] [US2] Create MedicationViewModel.swift in Peppermint/ViewModels/ with @Published properties for selectedMedication, categories array, ObservableObject conformance
- [X] T033 [US2] Create CompartmentDetailSheet.swift in Peppermint/Views/Constructor/ as SwiftUI sheet with text fields for medication name, date picker for expiration, category dropdown, color picker
- [X] T034 [US2] Implement medication assignment in MedicationViewModel.swift creating Medication CoreData entity, linking to Compartment, persisting to CoreData
- [X] T035 [US2] Add 3D text labels to Scene3DView.swift using SCNText geometry with medication.name, positioned above compartments, billboard constraint to face camera
- [X] T036 [US2] Configure text label styling in Scene3DView.swift: UIFont.systemFont Dynamic Type, UIColor.label for Dark Mode support, 0.5mm extrusion depth
- [X] T037 [US2] Implement expiration date logic in Medication entity computed properties: isExpiringSoon (30 days), isExpired (past date), warningColor (yellow/orange/red)
- [X] T038 [US2] Add expiration warning indicators to Scene3DView.swift as colored badges on compartments (yellow circle for 7-30 days, orange for <7 days, red for expired)
- [X] T039 [US2] Implement category filtering in OrganizerLibraryView.swift with picker menu, filter organizers where any compartment.medication.category matches selection
- [X] T040 [US2] Implement color filtering in OrganizerLibraryView.swift with color palette picker, filter organizers where any compartment.colorHex matches selection
- [X] T041 [US2] Update CompartmentDetailSheet.swift to show existing medication data when opening sheet on compartment with assigned medication (edit mode)
- [X] T042 [US2] Add category autocomplete to CompartmentDetailSheet.swift suggesting previously used categories from all medications in database

**Checkpoint**: ✅ User Stories 1 AND 2 both work independently - users can build organizers and assign medications with visual feedback

---

## Phase 5: User Story 3 - Schedule Medication Reminders (Priority: P3) ✅ COMPLETED

**Goal**: Users can set notification schedules for medications, see visual indicators on 3D compartments, receive timely notifications, and handle permission denial gracefully

**Independent Test**: Open organizer with medication → tap notification icon on compartment detail → set daily reminder 9:00 AM → visual indicator appears on compartment → simulate notification time → notification fires with medication name → tap notification → app opens to highlighted compartment

### Implementation for User Story 3

- [X] T043 [P] [US3] Create ReminderViewModel.swift in Peppermint/ViewModels/ with @Published properties for schedules array, ObservableObject conformance, UserNotifications authorization helpers
- [X] T044 [P] [US3] Create NotificationService.swift in Peppermint/Services/ wrapping UserNotifications framework with scheduleNotifications(for: ReminderSchedule), cancelNotifications(for: ReminderSchedule), requestAuthorization() methods
- [X] T045 [US3] Add reminder scheduling UI to CompartmentDetailSheet.swift with time pickers, frequency selector (daily/weekly/custom), day-of-week selector for weekly
- [X] T046 [US3] Implement reminder creation in ReminderViewModel.swift creating ReminderSchedule CoreData entity with JSON-encoded timesOfDay and daysOfWeek arrays, linking to Medication
- [X] T047 [US3] Register UserNotifications in NotificationService.swift with UNUserNotificationCenter, set delegate, request authorization with .alert + .sound + .badge
- [X] T048 [US3] Generate UNNotificationRequest in NotificationService.swift with medication.name in content.title, compartment location in content.body, UNCalendarNotificationTrigger for scheduled time
- [X] T049 [US3] Add reminder indicators to Scene3DView.swift as bell badge SF Symbol overlays on compartments with active ReminderSchedule (enabled == true)
- [X] T050 [US3] Implement notification tap handling in PeppermintApp.swift using UNUserNotificationCenterDelegate, parse notification userInfo to identify compartment, navigate to Scene3DView with highlighted compartment
- [X] T051 [US3] Add permission denial UI in CompartmentDetailSheet.swift showing alert with "Notification permissions required" message and "Open Settings" button linking to UIApplication.openSettingsURLString
- [X] T052 [US3] Display next reminder time in CompartmentDetailSheet.swift by computing ReminderSchedule.nextOccurrence from timesOfDay/daysOfWeek, show formatted date/time
- [X] T053 [US3] Implement reminder persistence across app termination by using UNUserNotificationCenter.add(_:withCompletionHandler:) which schedules system-level notifications

**Checkpoint**: ✅ All user stories 1-3 are now independently functional - users can build, medicate, and set reminders for organizers

---

## Phase 6: User Story 4 - Export 3D Model for Printing (Priority: P4) ✅ COMPLETED

**Goal**: Users can export organizers as STL files in <5 seconds, share via iOS share sheet, and verify printability in slicer software

**Independent Test**: Open organizer with 2-3 compartments → tap "Export for 3D Printing" → progress indicator shows → STL file generated in <5s → iOS share sheet appears → share via AirDrop → recipient opens in PrusaSlicer without errors

### Implementation for User Story 4

- [X] T054 [P] [US4] Create STLExporter.swift in Peppermint/Services/ with export(organizer: OrganizerDesign, to: URL) throws method generating binary STL files
- [X] T055 [US4] Implement Triangle struct in STLExporter.swift with normal: SIMD3<Float>, v1/v2/v3: SIMD3<Float>, auto-calculating normals from counter-clockwise vertices
- [X] T056 [US4] Implement BinarySTLExporter class in STLExporter.swift writing 80-byte header + UInt32 triangle count + 50-byte triangles (normal + 3 vertices + 2-byte attribute) in little-endian format
- [X] T057 [US4] Create CompartmentGeometry struct in STLExporter.swift with generateTriangles(position: SIMD3<Float>, connectors: [ConnectorSpec]) -> [Triangle] for box faces + friction-fit geometry
- [X] T058 [US4] Implement friction-fit tab/groove geometry generation in CompartmentGeometry using cantilever snap-tab dimensions from research.md (2.0mm tab height, 1.2mm groove depth, 0.3mm tolerance)
- [X] T059 [US4] Add export button to Scene3DView.swift toolbar calling OrganizerViewModel.exportToSTL() method
- [X] T060 [US4] Implement exportToSTL() in OrganizerViewModel.swift iterating compartments, calling STLExporter.export(), saving to temporary directory
- [X] T061 [US4] Add progress indicator to Scene3DView.swift using ProgressView with percentage or spinner, shown during STL generation
- [X] T062 [US4] Implement iOS share sheet in OrganizerViewModel.swift using UIActivityViewController with STL file URL, present modally after export completes
- [X] T063 [US4] Create ExportHistory CoreData entity record in OrganizerViewModel.swift after successful export, storing fileName, fileSize, compartmentCount, exportDuration
- [X] T064 [US4] Add error handling to STLExporter.swift for invalid geometry (overlapping compartments, too-small connectors), throw descriptive errors with simplification suggestions

**Checkpoint**: ✅ All user stories 1-4 are now independently functional - users can build, medicate, set reminders, and export organizers

---

## Phase 7: User Story 5 - Manage Multiple Organizer Designs (Priority: P5)

**Goal**: Users can create multiple organizers, view library with thumbnails, open/edit/save organizers, rename/duplicate/delete designs

**Independent Test**: Create 2-3 organizers with different names → navigate to library → all appear as thumbnails → tap one → opens in 3D view → modify structure → save → changes persist → long-press → rename/duplicate/delete options work

### Implementation for User Story 5

- [ ] T065 [US5] Add "Create New Organizer" button to OrganizerLibraryView.swift navigating to Scene3DView with new empty OrganizerDesign entity
- [ ] T066 [US5] Implement organizer loading in OrganizerViewModel.swift fetching OrganizerDesign by UUID, loading all related compartments/medications into Scene3DView
- [ ] T067 [US5] Update save functionality in OrganizerViewModel.swift to handle both create (new organizer) and update (existing organizer) cases, updating modifiedAt timestamp
- [ ] T068 [US5] Add long-press context menu to OrganizerLibraryView.swift thumbnail items showing "Rename", "Duplicate", "Delete" options
- [ ] T069 [US5] Implement rename functionality in OrganizerLibraryView.swift with text field alert, updating OrganizerDesign.name, persisting to CoreData
- [ ] T070 [US5] Implement duplicate functionality in OrganizerLibraryView.swift creating deep copy of OrganizerDesign + all compartments + all medications + all reminder schedules with new UUIDs
- [ ] T071 [US5] Implement delete functionality in OrganizerLibraryView.swift with confirmation alert, removing OrganizerDesign from CoreData (cascade deletes compartments)
- [ ] T072 [US5] Add organizer name text field to Scene3DView.swift toolbar allowing in-place editing of OrganizerDesign.name
- [ ] T073 [US5] Implement thumbnail grid layout in OrganizerLibraryView.swift using LazyVGrid with 2 columns, displaying OrganizerDesign.thumbnailData images and names
- [ ] T074 [US5] Add empty state to OrganizerLibraryView.swift showing "No organizers yet" message with "Create New Organizer" button when CoreData fetch returns 0 results

**Checkpoint**: All user stories 1-5 should now be independently functional - complete app with all MVP and enhancement features

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories, accessibility, performance optimization

- [ ] T075 [P] Add VoiceOver labels to Scene3DView.swift compartments using UIAccessibilityElement with projected 3D-to-2D coordinates, labels like "Compartment with Aspirin medication"
- [ ] T076 [P] Implement Reduce Motion support in Scene3DView.swift checking UIAccessibility.isReduceMotionEnabled, disabling animations when true
- [ ] T077 [P] Add haptic feedback to Scene3DView.swift using UIImpactFeedbackGenerator on compartment snap-to-grid, UINotificationFeedbackGenerator on save success
- [ ] T078 [P] Implement Dark Mode color adjustments in Scene3DView.swift using UIColor.systemBackground for scene background, UIColor.label for text materials
- [ ] T079 [P] Add Dynamic Type support to all SwiftUI text fields in CompartmentDetailSheet.swift using .font(.body) scalable fonts
- [ ] T080 [P] Optimize 3D rendering in Scene3DView.swift with SCNLevelOfDetail for distant compartments, .multisampling2X antialiasing, frustum culling enabled
- [ ] T081 [P] Add 50-compartment limit validation in OrganizerViewModel.swift showing alert when user tries to add 51st compartment
- [ ] T082 [P] Implement collision detection performance optimization in OrganizerViewModel.swift using spatial partitioning grid to check only nearby compartments
- [ ] T083 [P] Add app launch performance tracking in PeppermintApp.swift measuring time from didFinishLaunchingWithOptions to first frame, logging if >2 seconds
- [ ] T084 [P] Create app icon in Assets.xcassets using SF Symbol "pills" or custom design following Apple HIG guidelines
- [ ] T085 Run VoiceOver navigation testing on PeppermintUITests/AccessibilityTests.swift ensuring all primary tasks completable without vision
- [ ] T086 Validate STL export with PrusaSlicer integration test loading generated STL, checking for manifold errors, verifying 2mm min wall thickness

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3 → P4 → P5)
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Independent from US1 but builds on it (needs organizers with compartments)
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Independent from US1/US2 but builds on them (needs medications assigned)
- **User Story 4 (P4)**: Can start after Foundational (Phase 2) - Independent from US1/US2/US3 but needs organizers with compartments
- **User Story 5 (P5)**: Can start after Foundational (Phase 2) - Independent from US1/US2/US3/US4 but provides management for organizers

**Note**: While stories are technically independent after Foundational phase, they build on each other logically (P2 needs organizers from P1, P3 needs medications from P2). Recommend sequential implementation in priority order for best user experience.

### Within Each User Story

- Models before services
- Services before ViewModels
- ViewModels before Views
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- **Setup (Phase 1)**: Tasks T003, T004, T005, T006, T007 can run in parallel (different files, no dependencies)
- **Foundational (Phase 2)**: Tasks T010, T012, T013, T014, T017 can run in parallel (different files, no dependencies)
- **User Story 1**: Tasks T018, T019, T020 can run in parallel (different files, no dependencies)
- **User Story 2**: Tasks T032, T033 can run in parallel (different files, no dependencies)
- **User Story 3**: Tasks T043, T044 can run in parallel (different files, no dependencies)
- **User Story 4**: Tasks T054, T055 can run in parallel (different files, no dependencies)
- **Polish (Phase 8)**: All tasks T075-T084 can run in parallel (different files, cross-cutting concerns)

**Once Foundational phase completes**: All user story phases (3-7) can start in parallel if team capacity allows

---

## Parallel Example: User Story 1

```bash
# Launch all parallel tasks for User Story 1 together:
Task: "T018 [P] [US1] Create OrganizerViewModel.swift"
Task: "T019 [P] [US1] Create Scene3DService.swift"
Task: "T020 [P] [US1] Create FrictionFitGenerator.swift"

# Wait for completion, then sequential tasks:
Task: "T021 [US1] Create Scene3DView.swift"  # Depends on T019 (Scene3DService)
Task: "T022 [US1] Implement compartment geometry"  # Depends on T021
# ...continue sequentially
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready

**MVP Deliverable**: Users can create custom pill organizers in 3D, manipulate them with gestures, and save designs. This is the core value proposition.

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Add User Story 4 → Test independently → Deploy/Demo
6. Add User Story 5 → Test independently → Deploy/Demo
7. Add Polish (Phase 8) → Final release

Each story adds value without breaking previous stories.

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (T018-T031)
   - Developer B: User Story 2 (T032-T042)
   - Developer C: User Story 3 (T043-T053)
   - Developer D: User Story 4 (T054-T064)
3. Stories complete and integrate independently
4. Developer E: User Story 5 (T065-T074)
5. All developers: Polish (T075-T086) in parallel

---

## Notes

- [P] tasks = different files, no dependencies on incomplete work
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- File paths use Xcode project structure: `Peppermint/` prefix for all source files
- SceneKit chosen over RealityKit per research.md decision for mature APIs and STL export
- 5mm snap-to-grid system enforced throughout (SnapToGridCalculator)
- Friction-fit connectors auto-generated based on neighbor detection (FrictionFitGenerator)
- CoreData encrypted with FileProtectionType.complete for health data privacy
- 60 fps target enforced with Metal rendering, .multisampling2X antialiasing
- STL export uses custom binary writer (not library) per research.md decision
- No tests explicitly requested in spec.md, so test tasks omitted (tests are optional)
