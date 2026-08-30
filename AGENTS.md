# CSNotes Engineering Instructions

## Product

CSNotes is a native Apple note-taking application designed primarily for Computer Science students.

The application targets:

- iPadOS
- macOS
- iOS

The product combines:

- structured block-based notes
- typed text
- source code
- mathematical content
- Apple Pencil drawings
- course organization

The core document model is inspired by block-based editors such as Notion, but the application must remain optimized for Computer Science education.

## Current Repository State

This repository is currently in the initial Xcode template state.

The Xcode project, targets, product names, bundle identifiers, and Swift module are still named `Swordfinger的Note` / `Swordfinger_Note`. Do not rename the project, targets, files, bundle identifiers, signing settings, provisioning profiles, or entitlements unless explicitly requested.

Current targets:

- `Swordfinger的Note`: app target
- `Swordfinger的NoteTests`: unit test target using Swift Testing
- `Swordfinger的NoteUITests`: UI test target using XCTest/XCUIAutomation

Current app files:

- `Swordfinger的Note/ContentView.swift`
- `Swordfinger的Note/Item.swift`
- `Swordfinger的Note/Swordfinger_NoteApp.swift`
- `Swordfinger的Note/Assets.xcassets`

Current test files:

- `Swordfinger的NoteTests/Swordfinger_NoteTests.swift`
- `Swordfinger的NoteUITests/Swordfinger_NoteUITests.swift`
- `Swordfinger的NoteUITests/Swordfinger_NoteUITestsLaunchTests.swift`

Current SwiftData setup:

- `Item` is the only `@Model` type.
- `Swordfinger_NoteApp` creates a persistent `ModelContainer` with `Item.self`.
- `ContentView` uses `@Query` to display timestamp-based template items.

The current app does not yet implement CSNotes features.

## Technology Stack

Use Apple-native technologies unless there is a strong technical reason not to.

Primary technologies:

- Swift
- SwiftUI
- SwiftData
- PencilKit
- CloudKit
- XCTest / Swift Testing as appropriate

Avoid third-party dependencies unless explicitly approved.

Do not introduce:

- Firebase
- Supabase
- Realm
- React Native
- Electron
- web technologies

unless explicitly requested.

## Platform Strategy

The same domain models should be shared across macOS, iPadOS, and iOS.

Platform-specific UI is allowed and encouraged when appropriate.

Primary platform responsibilities:

iPadOS:

- note creation
- Apple Pencil
- drawing
- typing
- mixed handwritten and structured notes

macOS:

- keyboard-focused editing
- code editing
- organization
- search
- course management

iOS:

- reading
- search
- quick capture
- lightweight editing

Do not force identical interfaces across all platforms.

## Architecture

Use a feature-oriented architecture.

Preferred project organization:

```text
CSNotes/
  App/
  Models/
  Features/
    Courses/
    Pages/
    Editor/
      Blocks/
      PencilKit/
  Services/
    Search/
    Sync/
    Export/
  Shared/
    Components/
    Extensions/
```

While the project is still named `Swordfinger的Note`, create new source groups under the existing app target path unless a project rename has been explicitly requested.

Keep files focused.

Avoid very large SwiftUI views.

If a SwiftUI view becomes complex, extract meaningful components.

Business logic should not be embedded directly inside large view bodies.

Do not create unnecessary abstraction layers.

Prefer simple native Swift patterns over speculative architecture.

## Domain Model

The initial hierarchy is:

```text
Course
  -> NotePage
    -> NoteBlock
```

A `Course` contains ordered `NotePage` values.

A `NotePage` contains ordered `NoteBlock` values.

A `NoteBlock` represents one semantic unit inside a page.

Initial block types:

- paragraph
- heading
- code
- drawing

The architecture should make adding future block types possible without rewriting the entire editor.

Possible future block types include:

- equation
- image
- PDF
- callout
- algorithm
- diagram

Do not implement future block types unless explicitly requested.

## Block Editor Rules

The editor is block-based.

Each block:

- has a stable identifier
- belongs to one page
- has an explicit order
- can eventually be reordered
- can eventually be deleted
- stores content appropriate for its block type

Do not implement the editor as one giant rich-text document.

Do not implement the entire page as one PencilKit canvas.

Drawing must exist as a drawing block.

Code must exist as a code block.

Text must remain structured.

## PencilKit

Use PencilKit for Apple Pencil drawing.

Drawing functionality must be isolated from the rest of the editor.

Prefer:

```text
SwiftUI
  -> PencilCanvasView wrapper
    -> PKCanvasView
      -> PKDrawing
```

Persist `PKDrawing` using its data representation.

Do not convert drawings to raster images for primary persistence.

Preserve editable stroke data.

Drawing persistence must not block the main UI unnecessarily.

## SwiftData

Use SwiftData for local persistence.

Models should remain understandable and explicit.

Avoid storing transient UI state in persistent models.

Large binary data such as PencilKit drawing data should be handled appropriately rather than mixed with normal text fields without consideration.

Do not enable or redesign CloudKit synchronization unless explicitly requested.

Use in-memory SwiftData containers for previews and model/persistence tests.

## SwiftUI

Prefer native SwiftUI components.

Prefer:

- `NavigationSplitView` where appropriate
- `NavigationStack` on compact layouts
- platform-adaptive controls
- system typography
- system keyboard shortcuts

Avoid custom UI when a native component already solves the problem well.

Do not optimize visual polish before core behavior works.

Keep editor, list, sidebar, row, and block views separate as the app grows.

## Code Quality

Use descriptive names.

Avoid one-letter variable names except conventional short closures where clarity is preserved.

Prefer small functions.

Avoid duplicated logic.

Do not introduce speculative abstractions.

Do not add unnecessary comments.

Comments should explain why, not restate what the code does.

Do not leave dead code.

Do not leave commented-out implementations.

Do not silently suppress compiler warnings.

## Scope Discipline

Only modify files necessary for the requested task.

Do not refactor unrelated working code.

Do not implement features that were not requested.

If you identify unrelated problems, report them instead of automatically changing them.

Never perform broad architectural rewrites without explaining the reason first.

## Build Discipline

After meaningful implementation changes:

1. Inspect affected files.
2. Run the appropriate build.
3. Run relevant tests.
4. Fix compilation failures caused by the changes.
5. Report remaining issues.

For Apple platform code, prefer Xcode build tooling when practical.

Never claim that a feature works unless compilation or relevant verification has been performed when the environment allows it.

Do not change code signing, Team, bundle identifiers, provisioning profiles, or entitlements unless explicitly requested.

Documentation-only changes do not require a build unless the user explicitly asks for one.

## Testing

Add tests for non-trivial domain logic.

Prefer testing:

- model behavior
- ordering
- serialization
- persistence-related transformations
- reusable business logic

Do not create meaningless tests solely to increase test count.

UI testing is not required for every visual change.

## Git

Do not create branches unless explicitly requested.

Do not commit changes unless explicitly requested.

Do not push anything unless explicitly requested.

Never rewrite Git history unless explicitly requested.

Before making significant changes, inspect git status.

Never overwrite unrelated uncommitted user changes.

## Working Process

For each substantial task:

1. Read this `AGENTS.md`.
2. Inspect relevant existing code.
3. Understand the current implementation before editing.
4. State a concise implementation plan.
5. Make the smallest coherent set of changes.
6. Build and test.
7. Review the diff.
8. Report:
   - files changed
   - behavior implemented
   - verification performed
   - known limitations

If requirements conflict with the existing architecture, explain the conflict before performing a large redesign.

## Current Development Principle

We are building the application incrementally.

Prioritize vertical slices that work end-to-end.

Do not attempt to build the entire product in one task.

The initial goal is:

```text
Course
  -> Page
    -> Text Block
    -> Drawing Block
    -> persistence
```

After that foundation is stable, additional block types and synchronization will be added.
