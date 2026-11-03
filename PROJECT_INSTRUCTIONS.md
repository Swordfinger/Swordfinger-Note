# FingerNote — Project Instructions

## Product

FingerNote is an Apple-native note-taking app designed primarily for Computer Science students.

Current working product name:
FingerNote

Historical/internal names may still appear in the repository:
- Swordfinger Note
- Swordfinger 的 Note
- CSNotes

Do not rename repository paths, bundle identifiers, targets, schemes, or persistence identifiers merely for branding cleanup unless explicitly requested.

The product direction is:

handwriting-first
+
structured notes
+
code-aware editing
+
future executable handwritten code

Primary platform:
iPad

Secondary platform:
macOS

Future:
iPhone
iCloud sync
possibly Web / Windows / Linux through a separate backend architecture.

---

## Technology

Prefer Apple-native technologies.

Current stack:

- Swift
- SwiftUI
- SwiftData
- PencilKit
- PKCanvasView / PKDrawing
- NavigationSplitView

Avoid introducing cross-platform frameworks or unnecessary dependencies unless explicitly justified.

---

## Document Architecture

Current hierarchy:

Course
└── NotePage
    └── NoteBlock

Current NoteBlock concepts include:

- Paragraph
- Heading
- Code
- Drawing

The editor is block-based internally.

Do not replace the current block architecture with a giant rich-text document or giant freeform canvas without an explicit architecture decision.

A future handwriting-first mixed editor is being considered, but its architecture is NOT finalized.

Possible future direction:

Drawing segment
CodeBlock
Drawing segment
TextBlock
Drawing segment

visually presented as one continuous note.

Do not treat this architecture as already decided.

---

## SwiftData Safety

Production persistence is disk-backed.

Existing persisted data must remain migration-safe.

When adding persisted fields to existing SwiftData models:

- strongly prefer optional fields,
- provide safe computed-property fallbacks,
- do not introduce mandatory fields that break existing records,
- do not reinterpret existing drawing coordinates unexpectedly.

Previous migration issue:

codeLanguageRawValue was initially mandatory and broke existing NoteBlock records.

Correct pattern:

optional raw-value storage
+
computed fallback

Follow the same strategy for future persisted enums/settings.

---

## Drawing Architecture

PKDrawing remains the single persistent source of truth for handwriting.

Current persistence flow:

PKCanvasView
→ PKDrawing
→ dataRepresentation()
→ NoteBlock.drawingData
→ SwiftData

Do not persist a second independent rasterized drawing.

Temporary rendered previews are acceptable, but they must be derived from PKDrawing.

Drawing paper backgrounds are metadata/presentation and must NOT be baked into PKDrawing.

---

## Drawing Logical Coordinates

DrawingBlock uses stable finite logical pages.

Current geometry:

legacySquare:
1600 × 1600

Sketch:
1000 × 700

Side Note:
1200 × 1200

Full Note:
1600 × 2200

These are logical PencilKit coordinates, NOT screen pixels.

Do not change logical page geometry based on:

- iPad model
- viewport width
- device rotation
- Split View
- Stage Manager

Presentation may scale.

PKDrawing coordinates must remain stable.

Existing drawings without a preset must continue to resolve to:

legacySquare = 1600 × 1600

Do NOT reinterpret old drawings as Side Note 1200 × 1200.

---

## Drawing Input

iPad drawing should be Apple Pencil-first.

Desired behavior:

Apple Pencil:
- draw
- erase
- use PKToolPicker

Finger:
- must not create ink
- may scroll/pan/zoom
- may interact with UI controls

Prefer native PencilKit input policy rather than custom touch filtering.

---

## Drawing Focus Mode

Inline DrawingBlocks are non-interactive document representations.

Tapping/expanding opens a focused Drawing editor.

This separation exists partly to avoid List row gesture conflicts such as:

- palm triggering context menu
- delete
- reorder
- long press

Focused PKCanvasView should remain outside conflicting parent-row gestures.

Do not regress this behavior.

---

## Drawing Presentation

Focused Drawing currently uses a fit-to-width baseline.

At normal focused scale:

- logical page width fits available viewport width,
- normal horizontal drifting should not occur,
- vertical scrolling is allowed when page height exceeds viewport.

Pinch zoom is supported.

Product-relative zoom concept:

1× = fit-width baseline

Zoomed state:
- horizontal + vertical pan allowed

Minimum zoom:
fitWidthScale

Maximum zoom:
approximately fitWidthScale × 4

Zoom/pan are presentation state only.

Do NOT persist:

- zoomScale
- contentOffset
- fitWidthScale

On meaningful viewport resize/rotation, returning safely to the new fit-width baseline is acceptable.

Paper backgrounds and PKDrawing strokes must remain aligned in the same logical coordinate system during zoom/pan.

---

## Drawing Paper Styles

Current paper concepts:

- Blank
- Lined
- Grid
- Dotted

Paper style and DrawingCanvasPreset are independent.

Do not create combined persistence cases such as:

lecturePaper
quickDiagram

Future templates may combine:

DrawingCanvasPreset
+
DrawingPaperStyle

but the underlying model remains separate.

---

## Drawing Creation UX

New Drawing flow:

Add Block
→ Drawing
→ New Drawing configuration
→ choose Canvas + Paper
→ Create
→ exactly one NoteBlock is inserted
→ focused Drawing editor opens

Defaults:

Side Note
+
Blank

Cancel must create nothing.

Do not create temporary SwiftData NoteBlocks while configuration UI is open.

legacySquare is migration-only and must not be offered as a normal creation choice.

---

## CodeBlock Input Safety

CodeBlock is code input, not natural-language input.

CodeBlock must disable system transformations that could mutate source code.

Where supported disable:

- autocorrection
- spell checking
- grammar checking
- automatic capitalization
- smart quotes
- smart dashes
- smart insert/delete
- unsafe text replacement
- Writing Tools if they can mutate source text

Code input must preserve:

- spaces
- indentation
- line breaks
- punctuation
- capitalization
- raw source text

Normal Paragraph/Text blocks should RETAIN normal system writing assistance.

Do not globally disable writing assistance across the app.

---

## Future Code Indentation

The next CodeBlock editing feature is language-aware input-time indentation.

It should NOT be implemented as a full formatter.

Preferred architecture:

small testable CodeIndentationEngine
+
native input interception

Basic behavior:

Return:
- preserve current indentation

Python-like opener:
:
→ add one indentation level

Brace-based opener:
{
→ add one indentation level

Initial indentation unit:
prefer stable spaces, likely 4 spaces unless current project conventions differ.

Do not implement aggressive code rewriting.

---

## Future Code Execution

Long-term goal:

typed or recognized code
→ CodeBlock
→ Run / Compile
→ stdout / stderr / errors inline

Initial likely languages:

- Python
- C++

Later possible languages:

- Java
- Go
- Rust
- Swift
- C
- JavaScript
- Haskell
- Racket
- Prolog

macOS may eventually execute local tools through Process.

iPad/iPhone will likely require a remote sandbox or selected embedded runtimes.

Do not implement execution until basic editing architecture is stable.

---

## Handwritten Code Vision

Core long-term differentiator:

Apple Pencil handwritten code
→ handwriting recognition
→ source-code normalization
→ user correction/confirmation
→ CodeBlock
→ compile/run
→ output

Do not reduce the product vision to merely “a notebook with executable CodeBlocks.”

The important combination is:

Apple Pencil handwriting
+
structured CS notes
+
executable code

---

## Handwriting-First Mixed Editor

This architecture is currently UNDER DISCUSSION.

Do not assume a final solution.

Ideas under consideration include:

- visually continuous handwritten document,
- structured Drawing/Text/Code blocks underneath,
- insertion of Code/Text between handwritten regions,
- splitting Drawing regions at safe whitespace,
- avoiding splitting through existing ink,
- maintaining meaningful semantic block boundaries.

A giant PKCanvas with arbitrary overlay views is NOT approved.

A segmented block-based hybrid is promising but NOT yet final.

Always audit/design before implementing this architecture.

---

## Navigation

Current navigation uses NavigationSplitView.

Normal conceptual layout:

Course | Pages | Note Editor

Immersive NotePage mode:

Note Editor

The user must be able to intentionally hide Course/Page navigation and restore it.

Selection must remain stable.

On macOS, preferred compact/detail state must not accidentally reopen the Courses column when entering immersive mode.

Do not replace NavigationSplitView with a custom navigation system unless absolutely necessary.

---

## NotePage Header

The NotePage document header includes:

- page title
- Created date
- Modified date

There must not be two visible copies of the page title.

The large document header should be part of the main document scroll and naturally leave the screen as the user scrolls down.

Do not keep a large fixed title/date region occupying screen space.

Do not fix duplicate-title issues using arbitrary padding.

---

## Scroll Ownership

Normal NotePage mode should behave as one vertical document.

INLINE blocks should not casually trap ordinary trackpad/touch scrolling.

Policy:

Inline:
document-first scrolling

Focused:
block-specific scrolling/editing allowed

Current inline Paragraph/Code behavior has been adjusted so their internal vertical scroll does not trap normal macOS document scrolling.

Be careful when introducing nested ScrollView/TextEditor/NSScrollView behavior.

---

## Trash / Delete Semantics

Course and NotePage use soft delete through:

trashedAt: Date?

Normal Delete:
Move to Trash

Permanent Delete:
only from Trash

Course trashing:
set Course.trashedAt only

Do NOT recursively mark child pages as trashed.

Restoring Course:
clear Course.trashedAt only

A separately trashed child Page must remain trashed.

NoteBlock does not currently participate in Trash.

Block deletion remains direct.

---

## Git Rules

Before meaningful work:

1. read AGENTS.md
2. inspect relevant code
3. explain/audit architecture when task is non-trivial
4. implement the smallest coherent change
5. build
6. inspect diagnostics
7. run git diff --check
8. inspect git diff
9. inspect git status
10. report what changed

Do NOT:

- create branches unless requested
- commit unless explicitly requested
- push unless explicitly requested
- change signing/team/bundle identifier unless requested

Checkpoint commit currently known:

a7cd4c9
feat: refine iPad handwriting and drawing experience

There are later changes after this commit that may still be uncommitted.

Always inspect git status instead of assuming the working tree is clean.

---

## Testing Environment Limitation

The Codex execution environment has been confirmed unable to access installed iOS Simulator runtimes.

Known symptoms:

- CoreSimulatorService connection became invalid
- Unable to discover Simulator runtimes
- xcodebuild -showdestinations only shows:
  Any iOS Simulator Device

Therefore:

- do not repeatedly retry simulator-based xcodebuild test,
- environment-level simulator failure is NOT a project failure,
- use BuildProject / normal builds,
- use compiler diagnostics,
- run pure/model tests where possible,
- run git diff --check,
- report unavailable simulator tests briefly.

User performs:

- Xcode simulator tests
- ⌘U where appropriate
- physical iPad testing
- Apple Pencil testing
- palm/gesture testing
- orientation testing
- Split View / Stage Manager testing

Codex should perform all Mac-side verification that is reasonably possible.

---

## Engineering Style

Prefer:

- minimal native Apple UI
- small SwiftUI views
- feature-oriented files
- stable persistence
- conservative changes
- explicit platform behavior where required
- testable pure logic separated from UI wrappers

Avoid:

- giant refactors during feature work
- unrelated cleanup
- arbitrary hard-coded device-specific dimensions
- custom gesture systems when native APIs work
- duplicated sources of truth