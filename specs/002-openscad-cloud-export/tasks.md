# Tasks: OpenSCAD-Based STL Export with Cloud Sync

**Input**: Design documents from `/specs/002-openscad-cloud-export/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/openscad-api-schema.json ✅, quickstart.md ✅

**Tests**: Not explicitly requested in specification - focusing on implementation tasks only.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `- [ ] [ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

iOS project structure: `Peppermint/` (app), `PeppermintTests/` (tests)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and CoreData schema migration

- [X] T001 Create CoreData model version 3 (Peppermint 3.xcdatamodel) based on version 2
- [X] T002 Add CloudKit capability to Xcode project (Signing & Capabilities → CloudKit → iCloud.com.peppermint.organizer)
- [X] T003 Create Peppermint.entitlements file with CloudKit container identifier
- [X] T004 [P] Create Peppermint/Config/ServerConfig.swift for OpenSCAD server URL configuration
- [X] T005 [P] Create Peppermint/Utilities/KeychainHelper.swift for secure token storage (future use)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: CoreData schema extensions and base models that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T006 Extend OrganizerDesign entity in Peppermint 3.xcdatamodel with cloud sync attributes (cloudID, lastSyncedAt, syncStatus, conflictVersion, cloudSyncEnabled)
- [X] T007 [P] Create PreviewCache entity in Peppermint 3.xcdatamodel with attributes (id, cacheKey, stlData, generatedAt, includesPillVisualization, triangleCount, fileSizeBytes)
- [X] T008 [P] Create SyncConflict entity in Peppermint 3.xcdatamodel (syncable="NO") with attributes (id, detectedAt, localVersionData, remoteVersionData, resolved, resolutionStrategy, resolvedAt)
- [X] T009 Add inverse relationships: OrganizerDesign.previewCache → PreviewCache, OrganizerDesign.conflicts → SyncConflict
- [X] T010 Set Peppermint 3.xcdatamodel as current version in Xcode model editor
- [X] T011 Create Peppermint/Models/OrganizerDesign+CloudSync.swift extension with syncStatusEnum, markForSync(), markSynced(), hasUnsyncedChanges properties
- [X] T012 Create Peppermint/Models/PreviewCache+CoreDataClass.swift with generateCacheKey() and isValid() methods using SHA256 hashing
- [X] T013 Create Peppermint/Models/SyncConflict+CoreDataClass.swift with create() and resolve() methods for conflict management
- [X] T014 Update DataPersistenceService.swift to support NSPersistentCloudKitContainer with automatic lightweight migration
- [X] T015 Configure DataPersistenceService with automaticallyMergesChangesFromParent and NSMergeByPropertyObjectTrumpMergePolicy

**Checkpoint**: ✅ Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Interactive 3D Preview with Server-Generated STL (Priority: P1) 🎯 MVP

**Goal**: Users can export organizer designs as high-quality STL files with interactive 3D preview (rotate/zoom/pan) showing semi-transparent colored compartments. Falls back to local generation when server unavailable.

**Independent Test**: User creates organizer with 3 colored compartments → taps "Export for 3D Printing" → interactive 3D preview loads in <2 seconds showing semi-transparent colored compartments → user rotates/zooms with gestures → confirms export → STL file downloads → opens in PrusaSlicer showing manifold geometry.

### Implementation for User Story 1

**OpenSCAD API Service (Server Communication)**:

- [X] T016 [P] [US1] Create Peppermint/Services/OpenSCADAPIService.swift with singleton pattern and base URL configuration
- [X] T017 [P] [US1] Implement OpenSCADRequest codable structs in OpenSCADAPIService.swift (organizerId, compartments, options)
- [X] T018 [P] [US1] Implement OpenSCADSuccessResponse and OpenSCADErrorResponse codable structs with metadata parsing
- [X] T019 [US1] Implement generateSTL(organizer:includePills:) async method using URLSession with 30s timeout
- [X] T020 [US1] Add base64 decoding for STL data in generateSTL() response handling
- [X] T021 [US1] Implement APIError enum (invalidResponse, serverError, timeout, invalidBase64) with error handling

**Preview Cache Service (Performance Optimization)**:

- [X] T022 [P] [US1] Create Peppermint/Services/PreviewCacheService.swift with NSManagedObjectContext dependency
- [X] T023 [US1] Implement getCachedSTL(for:includePills:) method checking cache validity via cacheKey comparison
- [X] T024 [US1] Implement cacheSTL(_:for:includePills:triangleCount:) method creating PreviewCache entity with hash-based invalidation
- [X] T025 [US1] Implement evictOldestCacheIfNeeded() private method enforcing 100MB cache size limit

**STL Loader (SceneKit Binary Parser)**:

- [X] T026 [P] [US1] Create Peppermint/Utilities/STLLoader.swift with static loadSTL(data:color:transparency:) method
- [X] T027 [US1] Implement binary STL parser reading 80-byte header + triangle count (uint32) from Data
- [X] T028 [US1] Parse STL triangles extracting vertices (SCNVector3) and normals from binary format (50 bytes per triangle)
- [X] T029 [US1] Create SCNGeometry from parsed vertices/normals using SCNGeometrySource and SCNGeometryElement
- [X] T030 [US1] Apply SCNMaterial with compartment color, 70% transparency (alpha = 0.7), and physicallyBased lighting
- [X] T031 [US1] Add STLError enum (invalidFormat, corruptedData, unsupportedVersion) for validation failures

**Export Preview ViewModel (Business Logic)**:

- [X] T032 [P] [US1] Create Peppermint/ViewModels/ExportPreviewViewModel.swift as ObservableObject with @MainActor
- [X] T033 [US1] Add @Published properties: isShowingPreview, isLoading, previewNode (SCNNode?), error (String?)
- [X] T034 [US1] Implement showPreview(for:) method triggering loadSTL() task with cache-first strategy
- [X] T035 [US1] Implement private loadSTL(for:includePills:) checking cache → server → fallback flow
- [X] T036 [US1] Implement loadPreviewFromSTL(_:organizer:) parsing STL with STLLoader and applying compartment colors
- [X] T037 [US1] Implement fallbackToLocalGeneration(organizer:) using existing STLExporter.swift with user notification
- [X] T038 [US1] Implement confirmExport(organizer:) generating final STL (includePills: false) and sharing via UIActivityViewController

**Export Preview View (Interactive UI)**:

- [X] T039 [P] [US1] Create Peppermint/Views/Export/ExportPreviewView.swift as SwiftUI sheet view
- [X] T040 [US1] Add NavigationView with "Preview" title and Cancel/Export STL toolbar buttons
- [X] T041 [US1] Implement conditional rendering: ProgressView (loading) → error display → SceneKitPreviewView (success)
- [X] T042 [US1] Add gesture hint text: "Rotate: 1 finger • Zoom: pinch • Pan: 2 fingers" with caption styling
- [X] T043 [US1] Wire "Export STL" button to ExportPreviewViewModel.confirmExport() with disabled state when preview nil

**SceneKit Integration**:

- [X] T044 [P] [US1] Create SceneKitPreviewView as UIViewRepresentable wrapping SCNView in Peppermint/Views/Export/ExportPreviewView.swift
- [X] T045 [US1] Configure SCNView with allowsCameraControl=true for pan/pinch/rotate gestures at 60fps
- [X] T046 [US1] Setup default camera (SCNCamera) positioned at (0, 0, 100) with autoenablesDefaultLighting
- [X] T047 [US1] Add rootNode (from STL) to scene with systemBackground color for light/dark mode support

**Organizer Detail View Integration**:

- [X] T048 [P] [US1] Add "Export for 3D Printing" button to existing ConstructorView.swift with cube.box SF Symbol
- [X] T049 [US1] Create @StateObject private var exportViewModel = ExportPreviewViewModel() in ConstructorView
- [X] T050 [US1] Add .sheet(isPresented: $exportViewModel.isShowingPreview) presenting ExportPreviewView
- [X] T051 [US1] Wire button action to exportViewModel.showPreview(for: organizer)

**VoiceOver Accessibility**:

- [X] T052 [US1] Add VoiceOver labels to ExportPreviewView: "Export" button, "Cancel" button, gesture hint accessibility description
- [X] T053 [US1] Ensure SceneKitPreviewView has accessibility label describing current organizer state

**Checkpoint**: At this point, User Story 1 (MVP) should be fully functional - users can export with interactive preview, server fallback works, cache optimizes repeat exports

---

## Phase 4: User Story 2 - Optional Cloud Backup (Priority: P2)

**Goal**: Users can optionally enable cloud backup to iCloud, syncing organizer designs automatically within 5 seconds when online. Local-only mode preserved by default.

**Independent Test**: User enables cloud backup in settings → creates new organizer → organizer syncs to iCloud → user logs in on different device → sees same organizer available.

### Implementation for User Story 2

**Persistence Controller CloudKit Integration**:

- [X] T054 [P] [US2] Add enableCloudKit() method to PersistenceController.swift setting UserDefaults.cloudSyncEnabled = true
- [X] T055 [US2] Implement enableCloudKitContainer() configuring NSPersistentCloudKitContainerOptions with iCloud.com.peppermint.organizer
- [X] T056 [US2] Enable persistent history tracking (NSPersistentHistoryTrackingKey) and remote change notifications in CloudKit store description
- [X] T057 [US2] Implement handleRemoteChange(_:) selector posting .cloudSyncCompleted notification on main thread
- [X] T058 [US2] Add disableCloudKitContainer() setting cloudKitContainerOptions to nil for local-only mode

**Cloud Backup Settings View**:

- [X] T059 [P] [US2] Create Peppermint/Views/Settings/CloudBackupSettingsView.swift with SwiftUI Form layout
- [X] T060 [US2] Add @AppStorage("cloudSyncEnabled") toggle with onChange handler checking iCloud availability
- [X] T061 [US2] Implement checkiCloudAvailability() using CKContainer.default().accountStatus with status handling
- [X] T062 [US2] Handle iCloud status cases: .available (enable sync), .noAccount/.restricted/.couldNotDetermine (show alert)
- [X] T063 [US2] Implement enableCloudSync() calling PersistenceController.enableCloudKit() and marking all existing organizers cloudSyncEnabled=true
- [X] T064 [US2] Implement disableCloudSync() setting all organizers cloudSyncEnabled=false without deleting cloud data
- [X] T065 [US2] Add sync status display: checkmark.circle.fill icon + "Enabled" text when cloudSyncEnabled is true
- [X] T066 [US2] Add "Sync Now" button posting .forceCloudSync notification when cloud backup enabled
- [X] T067 [US2] Implement lastSyncDate computed property fetching most recent OrganizerDesign.lastSyncedAt with RelativeDateTimeFormatter

**Settings Integration**:

- [X] T068 [US2] Add NavigationLink to CloudBackupSettingsView in existing app settings (Settings tab or menu)

**Organizer Sync State Management**:

- [X] T069 [P] [US2] Update OrganizerViewModel to call organizer.markForSync() on compartment edits when cloudSyncEnabled=true
- [X] T070 [US2] Display sync status indicators in organizer library: synced (checkmark), syncing (progress spinner), offline (cloud.slash), error (exclamationmark.triangle)

**Checkpoint**: At this point, User Story 2 should work independently - users can enable/disable cloud backup, organizers sync to iCloud, local-only mode preserved

---

## Phase 5: User Story 3 - Cross-Device Synchronization (Priority: P3)

**Goal**: Users with cloud backup enabled can work on same organizer across multiple devices with automatic conflict resolution when offline edits occur.

**Independent Test**: User edits organizer on iPhone → changes sync to iCloud → user opens same organizer on iPad → sees changes reflected → user edits on iPad → changes sync back → no data loss.

### Implementation for User Story 3

**Cloud Sync Service (Conflict Detection)**:

- [X] T071 [P] [US3] Create Peppermint/Services/CloudSyncService.swift as ObservableObject with @Published syncStatus and conflictDetected
- [X] T072 [US3] Implement setupConflictObserver() adding NotificationCenter observer for .NSPersistentStoreRemoteChange
- [X] T073 [US3] Implement handlePersistentHistoryChange(_:) fetching NSPersistentHistoryChangeRequest after lastHistoryToken
- [X] T074 [US3] Detect conflicts by checking if remote update (.update changeType) matches local hasChanges on same objectID
- [X] T075 [US3] Set conflictDetected=true and syncStatus=.conflict when conflict found, creating SyncConflict entity
- [X] T076 [US3] Implement hasLocalChanges(for:) checking object.hasChanges on NSManagedObjectContext
- [X] T077 [US3] Store lastHistoryToken (NSPersistentHistoryToken) for incremental conflict checking

**Conflict Resolution Strategies**:

- [X] T078 [P] [US3] Implement ResolutionStrategy enum in SyncConflict+CoreDataClass.swift (keepLocal, keepRemote, merge)
- [X] T079 [US3] Implement resolve(strategy:in:) method in SyncConflict extension applying selected strategy
- [X] T080 [US3] Handle .keepLocal: set organizer.syncStatus = .pending and increment conflictVersion forcing CloudKit push
- [X] T081 [US3] Handle .keepRemote: decode remoteVersionData JSON and apply to local organizer with syncStatus = .synced
- [X] T082 [US3] Handle .merge: rely on NSMergeByPropertyObjectTrumpMergePolicy (already configured) for property-level last-write-wins
- [X] T083 [US3] Mark conflict resolved=true with resolutionStrategy and resolvedAt timestamp after applying

**Conflict Resolution UI**:

- [X] T084 [P] [US3] Add @StateObject private var syncService = CloudSyncService() to OrganizerLibraryView (or main organizer list view)
- [X] T085 [US3] Call syncService.setupConflictObserver() in .onAppear modifier
- [X] T086 [US3] Add .alert("Sync Conflict Detected", isPresented: $syncService.conflictDetected) with 3 action buttons
- [X] T087 [US3] Wire "Keep This Device's Changes" button to syncService.resolveConflict(strategy: .keepLocal)
- [X] T088 [US3] Wire "Use iCloud Version" button to syncService.resolveConflict(strategy: .keepRemote)
- [X] T089 [US3] Wire "Merge (Recommended)" button to syncService.resolveConflict(strategy: .merge) with cancel role

**Multi-Device Sync Indicators**:

- [X] T090 [US3] Add real-time sync status updates by observing .cloudSyncCompleted notification in organizer list
- [X] T091 [US3] Refresh organizer list UI when remote changes detected (fetch updated data from viewContext)

**Checkpoint**: At this point, User Story 3 should work independently - users can edit on multiple devices, conflicts are detected and resolved, property-level merge preserves data

---

## Phase 6: User Story 4 - Medication Visualization in 3D Preview (Priority: P4) 🔮 Future Enhancement

**Goal**: Users can see pill shapes inside compartments in 3D preview when medication.name is filled. Pills appear only in preview, NOT in export STL. Helps verify medication layout before printing.

**Independent Test**: User creates compartment → enters medication name "Aspirin" → opens preview → sees semi-transparent compartment with pill shapes inside → rotates to verify → exports → STL contains only empty compartment geometry.

### Implementation for User Story 4

**Medication Entity Extensions**:

- [X] T092 [P] [US4] Extend Medication entity in Peppermint 3.xcdatamodel with pillShape (String, default "round"), pillDiameter (Float, default 8.0), pillLength (Float, default 8.0)
- [X] T093 [US4] Create Peppermint/Models/Medication+Visualization.swift extension with shouldVisualize computed property (checks name not empty)
- [X] T094 [US4] Implement PillGeometry codable struct in Medication extension (shape, diameter, length) for OpenSCAD API

**OpenSCAD API Pill Visualization**:

- [X] T095 [P] [US4] Update OpenSCADAPIService.generateSTL() to include medication geometry when includePills=true
- [X] T096 [US4] Modify CompartmentGeometry struct adding optional medication property (MedicationGeometry)
- [X] T097 [US4] Only populate medication field when compartment.medication.shouldVisualize == true (FR-017: medication.name filled)
- [X] T098 [US4] Send pillShape, pillDiameter, pillLength to server for round/oblong/capsule/oval rendering

**Preview Toggle UI**:

- [X] T099 [P] [US4] Add @Published var showPillsInPreview = false to ExportPreviewViewModel
- [X] T100 [US4] Implement togglePillVisualization() method reloading STL with updated includePills parameter
- [X] T101 [US4] Add Toggle("Show Pills", isOn: $viewModel.showPillsInPreview) to ExportPreviewView toolbar with .onChange handler
- [X] T102 [US4] Ensure export always uses includePills: false in confirmExport() (FR-019: pills excluded from export STL)

**Cache Key Pill Support**:

- [X] T103 [US4] Update PreviewCache.generateCacheKey() to include medication.name, pillShape, pillDiameter, pillLength when includePills=true
- [X] T104 [US4] Ensure separate cache entries for preview-with-pills vs export-without-pills (different cacheKey values)

**Checkpoint**: At this point, User Story 4 should work independently - users can toggle pill visualization in preview, pills appear only when medication.name filled, export STL remains clean

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and final quality checks

- [X] T105 [P] Add error analytics tracking for OpenSCAD server failures (count fallback usage for monitoring)
- [X] T106 [P] Implement retry logic with exponential backoff (1s, 2s, 4s max 3 attempts) in OpenSCADAPIService before fallback
- [ ] T107 [P] Add CloudKit debugging logs: Edit Scheme → Run → Arguments → `-com.apple.CoreData.CloudKitDebug 1`
- [ ] T108 Verify manifold validation: Test exported STL files in PrusaSlicer for 100% manifold success rate (SC-016)
- [ ] T109 Performance test: Measure preview load time <2 seconds for 15-compartment organizer (SC-002)
- [ ] T110 Performance test: Verify 60fps gesture response during pan/pinch/rotate on iPhone 13+ (SC-003)
- [ ] T111 Network test: Verify fallback to local generation when server unreachable with 100% success rate (SC-006)
- [ ] T112 Cache test: Confirm cache reduces server load by measuring hit rate after repeat exports (target 60% - SC-007)
- [ ] T113 Multi-device test: Verify cloud sync completes within 5 seconds for 90% of changes on two devices (SC-008)
- [ ] T114 Conflict test: Simulate offline edits on 2 devices, verify zero data loss with conflict resolution (SC-009)
- [ ] T115 [P] Add app icon if not already present (T084 from previous feature might already exist)
- [ ] T116 Code review: Verify all TODO comments resolved and no debug print statements left
- [ ] T117 Validate quickstart.md Integration Scenarios 1-4 with manual testing
- [ ] T118 Final build and archive for TestFlight/App Store submission

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - User Story 1 (P1): Independent after Foundational
  - User Story 2 (P2): Independent after Foundational (integrates with US1 but separately testable)
  - User Story 3 (P3): Depends on US2 (requires cloud backup infrastructure)
  - User Story 4 (P4): Depends on US1 (requires preview infrastructure)
- **Polish (Phase 7)**: Depends on completion of desired user stories (minimum US1 for MVP)

### User Story Dependencies

- **User Story 1 (P1 - MVP)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - No dependencies on US1, but integrates with OrganizerViewModel
- **User Story 3 (P3)**: MUST complete User Story 2 first (requires cloud backup to be enabled)
- **User Story 4 (P4 - Future)**: MUST complete User Story 1 first (requires preview infrastructure)

### Within Each User Story

**User Story 1 (P1)** - 5 parallel workstreams:
1. OpenSCAD API Service (T016-T021)
2. Preview Cache Service (T022-T025)
3. STL Loader (T026-T031)
4. Export Preview ViewModel (T032-T038)
5. Export Preview View + SceneKit (T039-T047, T044-T047)

Then sequential: Organizer Integration (T048-T051) → Accessibility (T052-T053)

**User Story 2 (P2)** - 3 parallel workstreams:
1. Persistence Controller (T054-T058)
2. Cloud Backup Settings View (T059-T067)
3. Organizer Sync State (T069-T070)

Then sequential: Settings Integration (T068)

**User Story 3 (P3)** - 3 parallel workstreams:
1. Cloud Sync Service (T071-T077)
2. Conflict Resolution (T078-T083)
3. Conflict UI (T084-T089)

Then sequential: Multi-Device Indicators (T090-T091)

**User Story 4 (P4)** - 4 parallel workstreams:
1. Medication Extensions (T092-T094)
2. OpenSCAD API Pill Support (T095-T098)
3. Preview Toggle UI (T099-T102)
4. Cache Key Updates (T103-T104)

### Parallel Opportunities

**Phase 1 Setup** - All tasks (T001-T005) can run in parallel

**Phase 2 Foundational** - 3 parallel groups:
- Group A: T006 (OrganizerDesign)
- Group B: T007 (PreviewCache), T008 (SyncConflict)
- Sequential after groups: T009-T015

**Phase 3 User Story 1** - Multiple parallel workstreams (see above)

**Phase 3-6** - If team has capacity, different developers can work on US1, US2, US4 in parallel (US3 must wait for US2)

**Phase 7 Polish** - Most tasks (T105-T107, T115-T116) can run in parallel, tests (T108-T114) run sequentially

---

## Parallel Example: User Story 1

```bash
# Launch OpenSCAD API Service tasks in parallel:
Task: "Create Peppermint/Services/OpenSCADAPIService.swift"
Task: "Implement OpenSCADRequest codable structs"
Task: "Implement OpenSCADSuccessResponse and OpenSCADErrorResponse"

# Launch STL Loader tasks in parallel:
Task: "Create Peppermint/Utilities/STLLoader.swift"
Task: "Implement binary STL parser"

# Launch Preview Cache Service tasks in parallel:
Task: "Create Peppermint/Services/PreviewCacheService.swift"
Task: "Implement getCachedSTL()"
Task: "Implement cacheSTL()"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T015) - **CRITICAL - blocks all stories**
3. Complete Phase 3: User Story 1 (T016-T053)
4. **STOP and VALIDATE**: Test interactive preview with 3-compartment organizer
5. Verify server fallback works (disconnect network, test export)
6. Verify cache works (export twice, check cache hit in logs)
7. Deploy/demo MVP if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 (P1) → Test independently → **Deploy/Demo (MVP!)**
3. Add User Story 2 (P2) → Test cloud sync on 2 devices → Deploy/Demo
4. Add User Story 3 (P3) → Test conflict resolution → Deploy/Demo
5. Add User Story 4 (P4 - optional future) → Test pill visualization → Deploy/Demo
6. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers (assuming 3 developers):

1. **All developers together**: Complete Setup (Phase 1) + Foundational (Phase 2)
2. **Once Foundational done**, split work:
   - **Developer A**: User Story 1 (T016-T053) - Critical path, largest workload
   - **Developer B**: User Story 2 (T054-T070) - Independent, can start immediately
   - **Developer C**: User Story 4 (T092-T104) - Can start infrastructure, waits for Dev A to finish US1 for integration testing
3. **Developer C switches to User Story 3** (T071-T091) once Developer B finishes User Story 2
4. **All developers together**: Polish & Testing (Phase 7)

---

## Notes

- [P] tasks = different files, no dependencies between them
- [Story] label (US1, US2, US3, US4) maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group (e.g., complete service implementation)
- Stop at any checkpoint to validate story independently before proceeding
- **MVP = User Story 1 only** (interactive preview with server-generated STL)
- User Story 2-3 add cloud sync (optional enhancement)
- User Story 4 adds pill visualization (future enhancement, marked 🔮 in spec)
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- Constitution compliance verified in plan.md - all principles PASS ✅
- Performance targets: <2s preview load (SC-002), 60fps gestures (SC-003), <5s cloud sync (SC-008)
- Offline-first preserved: FR-006 (server fallback), FR-008 (local-only mode)
