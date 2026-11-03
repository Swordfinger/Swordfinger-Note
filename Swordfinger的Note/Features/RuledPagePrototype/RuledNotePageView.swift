import SwiftUI
import SwiftData

struct NotePageBody: View {
    let page: NotePage

    var body: some View {
        if page.usesRuledPaper {
            RuledNotePageView(page: page)
                .id(page.id)
        } else {
            BlockEditorView(page: page, showsPageHeader: true)
        }
    }
}

struct RuledNotePageView: View {
    @Environment(\.modelContext) private var modelContext
    let page: NotePage
    @State private var saveError: String?

    var body: some View {
        Group {
            if let data = page.ruledDocumentData {
                if let content = try? RuledTextContent.decode(data) {
                    RuledNativeEditor(title: page.title, initialContent: content, onChange: save)
                } else {
                    ContentUnavailableView("无法读取横线纸内容，原始数据已保留", systemImage: "doc.badge.exclamationmark")
                }
            } else {
                RuledNativeEditor(title: page.title, initialContent: RuledTextContent(), onChange: save)
            }
        }
        .onAppear {
            if page.ruledDocumentData == nil { save(RuledTextContent()) }
        }
        .alert("笔记尚未保存", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("重试") { persist() }
            Button("关闭", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private func save(_ content: RuledTextContent) {
        do {
            page.ruledDocumentData = try content.encoded()
            page.modifiedAt = Date()
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func persist() {
        do {
            try modelContext.save()
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#if canImport(UIKit)
struct RuledNativeEditor: UIViewControllerRepresentable {
    let title: String
    let initialContent: RuledTextContent
    let onChange: (RuledTextContent) -> Void

    func makeUIViewController(context: Context) -> RuledPageEditorController {
        let controller = RuledPageEditorController()
        controller.titleText = title
        controller.load(initialContent)
        controller.onContentChanged = onChange
        return controller
    }

    func updateUIViewController(_ controller: RuledPageEditorController, context: Context) {
        controller.updateTitle(title)
        controller.onContentChanged = onChange
    }
}
#elseif os(macOS)
struct RuledNativeEditor: NSViewRepresentable {
    let title: String
    let initialContent: RuledTextContent
    let onChange: (RuledTextContent) -> Void

    func makeNSView(context: Context) -> RuledPageMacEditor {
        let editor = RuledPageMacEditor(frame: .zero)
        editor.load(initialContent)
        editor.updateTitle(title)
        editor.onContentChanged = onChange
        return editor
    }

    func updateNSView(_ editor: RuledPageMacEditor, context: Context) {
        editor.updateTitle(title)
        editor.onContentChanged = onChange
    }
}
#endif
