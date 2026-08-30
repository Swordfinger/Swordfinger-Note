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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
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

                Spacer()

                Button(action: copyCode) {
                    Label("Copy Code", systemImage: "doc.on.doc")
                }
            }

            ScrollView(.horizontal) {
                TextEditor(text: $block.textContent)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minWidth: 640, minHeight: 180)
                    .onChange(of: block.textContent) { _, _ in
                        onCodeChanged()
                    }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
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
