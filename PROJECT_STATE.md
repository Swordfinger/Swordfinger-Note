# FingerNote — Current Development State

Updated: 2026-09-05 (America/Vancouver). Reconciled with the user-provided September 2026 development-state snapshot after the auto-indentation implementation.

## Source of truth and working rules

- Actual repository: `/Users/swordfinger/Swordfinger-Note`.
- The ChatGPT project mirror initially contained no source files. It is not the Xcode repository.
- `PROJECT_INSTRUCTIONS.md` preserves the user's latest project instructions verbatim. Read it together with this file and `AGENTS.md` before continuing.
- The “Current Repository State” section in `AGENTS.md` is stale: the project has progressed beyond the template. The engineering rules still apply.
- Current temporary product name: FingerNote. Existing repository paths, targets, schemes, signing and persistence identifiers remain unchanged. No mass rename is planned.
- Checkpoint: `a7cd4c9` — `feat: refine iPad handwriting and drawing experience`.
- Work after that checkpoint is uncommitted. Inspect current Git status; do not reset it. No branch, commit, staging operation, or push was performed in this continuation.

## Existing implementation

- Apple-native SwiftUI + SwiftData + PencilKit; iPad primary, macOS secondary.
- Course → NotePage → NoteBlock; Paragraph, Heading, Code, Drawing blocks.
- Disk-backed production persistence; tests/previews use in-memory models.
- Course/Page rename, soft delete, Trash, restore, permanent deletion, and Empty Trash are implemented. Course → NotePage and NotePage → NoteBlock use cascade relationships; block order persists. Block deletion remains direct.
- Optional persisted enum raw values with safe fallbacks. Drawing data remains PKDrawing data; paper metadata is separate.
- Stable drawing pages: legacySquare 1600×1600, Sketch 1000×700, Side Note 1200×1200, Full Note 1600×2200.
- Drawing configuration creates exactly one block on Create, none on Cancel, then opens focused editing. New defaults: Side Note + Blank.
- Inline drawing previews; focused Pencil-only editing, paper backgrounds, fit-width baseline, zoom and zoomed pan.
- NotePage header scrolls in the document List; duplicate navigation title suppressed.
- Existing immersive navigation and inline scroll fixes were already in the working tree. The user reported no remaining issues before authorizing auto-indentation.
- App icon assets and project settings include pre-existing uncommitted changes; they were preserved.

## Product appearance and iPad configuration

- User-specified app icon direction: Apple-like minimalism, subtle notebook/paper feeling, a code-related `</>` symbol, and an orange slash accent. Page curls and stacked pages are not the final direction. Icon assets are still being adjusted for iOS/iPadOS and macOS; this is not recorded as a finalized icon.
- Native iPad rendering, generated launch screen, and four iPad orientations are configured: portrait, upside-down portrait, landscape left, and landscape right.
- `UIRequiresFullScreen` is not enabled, preserving support for Split View and Stage Manager. Physical behavior across these modes remains part of regression checks.
- The earlier oversized iPad appearance was identified as layout density/column sizing. The current adaptive layout retains NavigationSplitView and allocates more appropriate editor space.

## Completed: CodeBlock Return indentation

- Both inline and focused code use `CodeTextEditor`, a small UIViewRepresentable/NSViewRepresentable component owning its native text view. It replaces TextEditor plus ancestor-search configuration only for CodeBlock.
- iPad/iOS: `UITextView.insertText` intercepts a single newline outside marked-text composition and paste. Native insertion handles cursor and undo; delegate changes update the existing text binding.
- macOS: `NSTextView.insertNewline` handles Return; native `insertText(_:replacementRange:)` updates text, selection, undo and delegate callbacks.
- `CodeIndentationEngine` is pure and has no SwiftData dependency. Input positions are UTF-16 ranges with scalar-boundary checks.
- All languages preserve current-line leading spaces/tabs up to the cursor. New indentation uses four spaces.
- Python: trailing meaningful `:` adds one level.
- Swift, C, C++, Java, JavaScript: trailing meaningful `{` adds one level.
- Plain Text, Haskell, Racket, Prolog: preserve whitespace only.
- A small lexical scan skips line/block comments and quoted strings, including common multiline strings. This is not a parser or formatter.
- Replacing selected text uses an ordinary newline. Paste and existing source are not reformatted. Multi-selection on Mac and marked-text composition retain native behavior.
- Code-only input protections remain enabled; Paragraph is unchanged. Inline native scroll gestures pass to the document; focused code retains vertical scrolling.
- Existing `textContent` binding, modified-date callbacks, and persistence flow are preserved. No model/schema or drawing change was made.

## Verification

- macOS Xcode build: passed for arm64 and x86_64.
- Generic iOS device build: passed, without signing or deployment.
- Standalone Swift Testing: 13 tests in 2 suites passed, including parameterized Python cases, every exposed language family, comments/strings, middle insertion, selections, Unicode/CRLF, invalid ranges, native Mac Return/undo/redo, source insertion, and hosted inline/focused binding/layout.
- No production note store was opened for tests. Native Mac tests use temporary windows and string bindings.
- `scripts/test-code-editor.sh` reproduces the standalone tests on Mac with Xcode/Swift, without Simulator or loading the app/SwiftData store.
- Default sandbox initially blocked SwiftData compiler macros and SwiftPM caches. Authorized local execution allowed build and test verification.
- No iOS Simulator test was attempted; the known runtime/service limitation remains documented in the project instructions.
- Xcode emitted the standard skipped AppIntents metadata warning because this app has no AppIntents framework dependency.

## Physical verification still needed for this change

On iPad, in both inline and focused CodeBlock:

1. Python `if x:` then Return → four spaces; nested `    if x:` → eight spaces.
2. C++ `if (x) {` then Return → four spaces; repeat nested and in the middle of existing code.
3. Use software and hardware keyboard Return; check selection replacement, undo/redo, paste, and non-English composition.
4. Type `printf("hello");` and `my_variable_name`; verify punctuation and capitalization remain exact. Paragraph still has normal writing assistance.
5. Verify page scrolling over inline code, focused scrolling, long lines, and portrait/landscape widths.

On Mac, repeat language/nested/middle/selection/paste/undo checks in inline and focused code. Verify the page scrolls over inline blocks and focused code scrolls internally. Recheck header and immersive navigation alongside long code/paragraph content.

## Broader regression checks retained from the user snapshot

- iPad: header/title behavior, Paragraph writing assistance, exact CodeBlock input, paper/stroke alignment during zoom, Pencil-only drawing, Drawing creation/cancellation, all orientations, and Split View/Stage Manager.
- Mac: scrolling over Paragraph/Code/Drawing, entering and exiting immersive NotePage without losing selection, exact code punctuation, and long wrapped Paragraph/Code content with estimated heights.
- The user previously reported no remaining issues in the preceding stabilization work. That does not replace physical verification of the newly changed CodeBlock input component.

## Limits and next priorities

- First-version indentation only. No closing-brace dedent, paired-brace insertion, formatter, highlighting, compiler, or code execution.
- Lexical rules are conservative, not complete language grammars; exotic raw strings, regex literals, and language-specific continuation alignment are outside this milestone.
- Existing inline height estimation still counts logical lines. Very long wrapped lines may need a separate text-measurement improvement; this was not expanded into a page/editor redesign.
- New Return uses LF, retaining all existing text and any CRLF sequences.
- Complete the physical checks before the next CodeBlock editing increment.
- Handwriting-first mixed-editor architecture remains under discussion. No giant canvas, splitting of drawing regions, CloudKit synchronization, recognition, execution, or cross-platform backend is approved by this milestone.

## Roadmap and open architecture decision

- The supplied September snapshot lists auto-indentation as the immediate next feature. That item is now implemented and automatically verified; physical checks are the immediate next step.
- After those checks: CodeBlock editing UX improvements, possibly syntax highlighting, and a deliberate handwriting-first mixed-editor architecture decision.
- Ideas still under discussion include a continuous structured document, Drawing segments with inserted Code/Text blocks, and whitespace-aware splitting that avoids existing ink. A giant canvas with overlays is also a discussed candidate, not an approved design. None of these alternatives has been selected for implementation.
- Later milestones: handwritten-code recognition, source normalization and user correction, conversion into CodeBlock, execution, and inline stdout/stderr/errors; then export/PDF, iCloud/CloudKit, iPhone reading/text editing, and longer-term non-Apple access architecture. This roadmap does not authorize starting those features automatically.
- The product differentiator remains Apple Pencil handwriting + CS-oriented structured notes + code-aware editing + eventually handwritten executable code.
