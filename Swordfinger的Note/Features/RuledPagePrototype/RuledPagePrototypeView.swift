#if DEBUG && canImport(UIKit)
import SwiftUI

struct RuledPagePrototypeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            RuledPageEditor()
                .navigationTitle("Ruled Page Prototype")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("关闭并清空") { dismiss() }
                    }
                }
        }
    }
}

private struct RuledPageEditor: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> RuledPageEditorController {
        RuledPageEditorController()
    }

    func updateUIViewController(_ controller: RuledPageEditorController, context: Context) {}
}
#endif
