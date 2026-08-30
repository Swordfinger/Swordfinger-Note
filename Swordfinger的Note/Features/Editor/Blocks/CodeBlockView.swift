//
//  CodeBlockView.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
//

import SwiftUI
import SwiftData

struct CodeBlockView: View {
    @Bindable var block: NoteBlock
    let onCodeChanged: () -> Void

    @State private var isFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                CodeLanguagePicker(block: block, onCodeChanged: onCodeChanged)

                Spacer()

                Button {
                    isFocused = true
                } label: {
                    Label("Edit Code", systemImage: "arrow.up.left.and.arrow.down.right")
                }

                Button(action: copyCode) {
                    Label("Copy Code", systemImage: "doc.on.doc")
                }
            }

            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    TextEditor(text: $block.textContent)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(minWidth: max(geometry.size.width, 520), minHeight: 180)
                        .onChange(of: block.textContent) { _, _ in
                            onCodeChanged()
                        }
                }
            }
            .frame(minHeight: 180)
        }
        .padding(10)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
        #if os(macOS)
        .sheet(isPresented: $isFocused) {
            FocusedCodeEditorView(block: block, onCodeChanged: onCodeChanged)
                .frame(minWidth: 720, minHeight: 520)
        }
        #else
        .fullScreenCover(isPresented: $isFocused) {
            FocusedCodeEditorView(block: block, onCodeChanged: onCodeChanged)
        }
        #endif
    }

    private func copyCode() {
        Clipboard.copy(block.textContent)
    }
}

private struct CodeLanguagePicker: View {
    @Bindable var block: NoteBlock
    let onCodeChanged: () -> Void

    var body: some View {
        Picker("Language", selection: $block.codeLanguage) {
            ForEach(CodeBlockLanguage.allCases) { language in
                Text(language.rawValue).tag(language)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .onChange(of: block.codeLanguage) { _, _ in
            onCodeChanged()
        }
    }
}

private struct FocusedCodeEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var block: NoteBlock
    let onCodeChanged: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    CodeLanguagePicker(block: block, onCodeChanged: onCodeChanged)

                    Spacer()

                    Button(action: copyCode) {
                        Label("Copy Code", systemImage: "doc.on.doc")
                    }
                }

                GeometryReader { geometry in
                    ScrollView(.horizontal) {
                        TextEditor(text: $block.textContent)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .frame(minWidth: max(geometry.size.width, 720), minHeight: geometry.size.height)
                            .onChange(of: block.textContent) { _, _ in
                                onCodeChanged()
                            }
                    }
                }
            }
            .padding()
            .navigationTitle("Code")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func copyCode() {
        Clipboard.copy(block.textContent)
    }
}

private enum Clipboard {
    static func copy(_ text: String) {
        #if canImport(AppKit)
        importToPasteboard(text)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }

    #if canImport(AppKit)
    private static func importToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    #endif
}

#Preview {
    CodeBlockView(
        block: NoteBlock(
            order: 0,
            blockType: .code,
            textContent: "func greet() {\n    print(\"Hello\")\n}",
            codeLanguage: .swift
        ),
        onCodeChanged: {}
    )
    .padding()
    .modelContainer(for: [Item.self, Course.self, NotePage.self, NoteBlock.self], inMemory: true)
}
