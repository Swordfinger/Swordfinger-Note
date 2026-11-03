import Foundation
import Testing
#if SWIFT_PACKAGE
@testable import FingerNoteCode
#else
@testable import Swordfinger的Note
#endif

struct CodeIndentationEngineTests {
    @Test(arguments: [
        ("x = 1", "\n"),
        ("    x = 1", "\n    "),
        ("if x:", "\n    "),
        ("    if x:", "\n        "),
        ("\tif x:", "\n\t    "),
        ("    ", "\n    "),
        ("", "\n"),
        ("if x:   ", "\n    "),
        ("if x: # explanation", "\n    "),
        ("# if x:", "\n"),
        ("print('x:')", "\n"),
        ("value = 'unfinished:", "\n"),
        ("value = '''\nif x:", "\n"),
        ("value = '''x'''\nif x:", "\n    "),
        ("if x:\n    value = 1\n", "\n")
    ])
    func pythonReturn(text: String, expected: String) {
        #expect(insertion(text, language: .python) == expected)
    }

    @Test(arguments: [CodeBlockLanguage.swift, .c, .cpp, .java, .javascript])
    func braceLanguages(language: CodeBlockLanguage) {
        #expect(insertion("if (x) {", language: language) == "\n    ")
        #expect(insertion("    if (x) {", language: language) == "\n        ")
        #expect(insertion("if (x) { // comment", language: language) == "\n    ")
        #expect(insertion("if (x) { /* comment */", language: language) == "\n    ")
        #expect(insertion("if (x) { work(); }", language: language) == "\n")
        #expect(insertion("// {", language: language) == "\n")
        #expect(insertion("/* first line\n{", language: language) == "\n")
        #expect(insertion("let text = \"{\"", language: language) == "\n")
        #expect(insertion("let text = \"unfinished {", language: language) == "\n")
        #expect(insertion("    }", language: language) == "\n    ")
    }

    @Test(arguments: [CodeBlockLanguage.plainText, .haskell, .racket, .prolog])
    func remainingLanguagesOnlyPreserveWhitespace(language: CodeBlockLanguage) {
        #expect(insertion(" \t  value {", language: language) == "\n \t  ")
        #expect(insertion("    value:", language: language) == "\n    ")
    }

    @Test func multilineStringsAndNestedCommentsDoNotOpenBlocks() {
        #expect(insertion("const value = `line\n{", language: .javascript) == "\n")
        #expect(insertion("let value = \"\"\"\n{", language: .swift) == "\n")
        #expect(insertion("/* outer /* inner */\n{", language: .swift) == "\n")
        #expect(insertion("/* outer /* inner */ end */\nif x {", language: .swift) == "\n    ")
        #expect(insertion("print(\"escaped \\\" :\")", language: .python) == "\n")
    }

    @Test func middleOfDocumentUsesOnlyPrefixAtCursor() {
        let text = "start\n    if x:rest\nlast"
        let cursor = ("start\n    if x:" as NSString).length
        let selection = NSRange(location: cursor, length: 0)
        let inserted = CodeIndentationEngine.insertion(for: text, selection: selection, language: .python)
        #expect(inserted == "\n        ")
        #expect((text as NSString).replacingCharacters(in: selection, with: inserted ?? "") == "start\n    if x:\n        rest\nlast")
        #expect(CodeIndentationEngine.insertion(for: "if x:", selection: NSRange(location: 2, length: 0), language: .python) == "\n")
    }

    @Test func returnInsideLeadingWhitespaceOnlyCopiesPrefix() {
        #expect(CodeIndentationEngine.insertion(for: "    value", selection: NSRange(location: 2, length: 0), language: .python) == "\n  ")
    }

    @Test func nativeUTF16CursorHandlesUnicodeAndCRLF() {
        let prefix = "// 👩🏽‍💻\r\n    if café {"
        let text = prefix + "\r\nnext"
        #expect(CodeIndentationEngine.insertion(for: text, selection: NSRange(location: (prefix as NSString).length, length: 0), language: .swift) == "\n        ")
        #expect(insertion("if x:\r\n", language: .python) == "\n")
    }

    @Test func selectedTextKeepsOrdinaryNewlineReplacement() {
        let text = "if x:\n    old\nlast"
        let selection = (text as NSString).range(of: "    old")
        #expect(CodeIndentationEngine.insertion(for: text, selection: selection, language: .python) == "\n")
        #expect(CodeIndentationEngine.insertion(for: text, selection: NSRange(location: 0, length: (text as NSString).length), language: .python) == "\n")
    }

    @Test func invalidSelectionIsRejectedWithoutCrashing() {
        for range in [NSRange(location: NSNotFound, length: 0), NSRange(location: -1, length: 0), NSRange(location: 1, length: -1), NSRange(location: 99, length: 0), NSRange(location: 0, length: Int.max)] {
            #expect(CodeIndentationEngine.insertion(for: "if x:", selection: range, language: .python) == nil)
        }
        #expect(CodeIndentationEngine.insertion(for: "😀", selection: NSRange(location: 1, length: 0), language: .python) == nil)
    }

    private func insertion(_ text: String, language: CodeBlockLanguage) -> String? {
        CodeIndentationEngine.insertion(for: text, selection: NSRange(location: (text as NSString).length, length: 0), language: language)
    }
}
