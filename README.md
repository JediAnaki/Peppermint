# Peppermint

Peppermint is an iOS app for designing custom pill organizers in 3D, managing compartment medication details, and keeping organizer layouts saved locally.

## Features

- Organizer library with empty state and saved cards
- 3D constructor based on SceneKit
- Component library for adding compartments
- Compartment editing with medication details:
  - name
  - category
  - expiration date
  - notes
- Local persistence via Core Data
- Organizer thumbnail generation from 3D scene snapshots

## Tech Stack

- Swift 5.9
- SwiftUI
- SceneKit
- Core Data
- XcodeGen (`project.yml`)
- iOS 17.0+

## Project Structure

- `Peppermint/App` - app entry and root views
- `Peppermint/Views/Library` - organizer list and empty state
- `Peppermint/Views/Constructor` - 3D editor and detail sheets
- `Peppermint/ViewModels` - organizer and medication state logic
- `Peppermint/Services` - scene setup, persistence, geometry helpers
- `Peppermint/Models` - Core Data model classes
- `Peppermint/Resources` - localized strings and presets

## Run Locally

1. Generate Xcode project:

```bash
xcodegen generate
```

2. Open project:

```bash
open Peppermint.xcodeproj
```

3. Build and run `Peppermint` target in Xcode.

## Screenshots

> Add screenshot files to `docs/screenshots/` with the exact names below.

### Library Empty State
![Library Empty State](docs/screenshots/01-library-empty.png)

### Category Picker
![Category Picker](docs/screenshots/02-category-picker.png)

### Medication Details
![Medication Details](docs/screenshots/03-medication-details.png)

### 3D Constructor
![3D Constructor](docs/screenshots/04-constructor-3d.png)

### Library With Organizer
![Library With Organizer](docs/screenshots/05-library-with-item.png)

## Git Notes

Local agent/spec files are excluded via `.gitignore`:

- `.claude/`
- `.specify/`
- `CLAUDE.md`
- `specs/`
