#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/fingernote-code-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/Sources/FingerNoteCode" "$test_root/Tests/FingerNoteCodeTests"
cp "$repo_root/Swordfinger的Note/Models/CodeBlockLanguage.swift" \
   "$repo_root/Swordfinger的Note/Features/Editor/CodeIndentationEngine.swift" \
   "$repo_root/Swordfinger的Note/Features/Editor/CodeTextEditor.swift" \
   "$test_root/Sources/FingerNoteCode/"
cp "$repo_root/Swordfinger的NoteTests/CodeIndentationEngineTests.swift" \
   "$repo_root/Swordfinger的NoteTests/CodeTextEditorTests.swift" \
   "$test_root/Tests/FingerNoteCodeTests/"
cat > "$test_root/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "FingerNoteCode",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "FingerNoteCode"),
        .testTarget(name: "FingerNoteCodeTests", dependencies: ["FingerNoteCode"])
    ],
    swiftLanguageModes: [.v5]
)
PACKAGE
swift test --package-path "$test_root"
