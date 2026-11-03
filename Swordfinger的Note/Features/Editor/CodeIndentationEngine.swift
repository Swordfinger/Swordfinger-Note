import Foundation

/// Computes only the text inserted by Return; existing source is never reformatted.
nonisolated enum CodeIndentationEngine {
    static let indentUnit = "    "

    static func insertion(for text: String, selection: NSRange, language: CodeBlockLanguage) -> String? {
        let source = text as NSString
        guard selection.location != NSNotFound,
              selection.location >= 0,
              selection.length >= 0,
              selection.location <= source.length,
              selection.length <= source.length - selection.location,
              isScalarBoundary(selection.location, in: source),
              isScalarBoundary(selection.location + selection.length, in: source) else {
            return nil
        }

        // Replacing a selection keeps the native editor's ordinary Return behavior.
        guard selection.length == 0 else { return "\n" }

        let prefix = source.substring(to: selection.location)
        let line = prefix.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).last ?? ""
        let indentation = String(line.prefix { $0 == " " || $0 == "\t" })
        let opener: Character
        switch language {
        case .python:
            opener = ":"
        case .swift, .c, .cpp, .java, .javascript:
            opener = "{"
        case .plainText, .haskell, .racket, .prolog:
            return "\n" + indentation
        }

        let addsLevel = lastCodeCharacter(in: prefix, language: language) == opener
        return "\n" + indentation + (addsLevel ? indentUnit : "")
    }

    private static func isScalarBoundary(_ offset: Int, in source: NSString) -> Bool {
        guard offset > 0, offset < source.length else { return true }
        let before = source.character(at: offset - 1)
        let after = source.character(at: offset)
        return !(0xD800...0xDBFF).contains(before) || !(0xDC00...0xDFFF).contains(after)
    }

    /// A small lexical scan avoids treating comments or string contents as block openers.
    /// It deliberately does not try to parse expressions or infer continuation indentation.
    private static func lastCodeCharacter(in prefix: String, language: CodeBlockLanguage) -> Character? {
        let characters = Array(prefix)
        var index = 0
        var quote: Character?
        var isTripleQuote = false
        var blockCommentDepth = 0
        var isLineComment = false
        var lastCode: Character?

        func matches(_ value: Character, at offset: Int) -> Bool {
            index + offset < characters.count && characters[index + offset] == value
        }

        while index < characters.count {
            let character = characters[index]
            if character.isNewline {
                isLineComment = false
                lastCode = nil
            }

            if isLineComment {
                index += 1
                continue
            }

            if blockCommentDepth > 0 {
                if character == "*", matches("/", at: 1) {
                    blockCommentDepth -= 1
                    index += 2
                } else if language == .swift, character == "/", matches("*", at: 1) {
                    blockCommentDepth += 1
                    index += 2
                } else {
                    index += 1
                }
                continue
            }

            if let delimiter = quote {
                if character == "\\" {
                    index += min(2, characters.count - index)
                } else if character == delimiter,
                          !isTripleQuote || (matches(delimiter, at: 1) && matches(delimiter, at: 2)) {
                    index += isTripleQuote ? 3 : 1
                    quote = nil
                    isTripleQuote = false
                    lastCode = delimiter
                } else {
                    index += 1
                }
                continue
            }

            if language == .python, character == "#" {
                isLineComment = true
            } else if language != .python, character == "/", matches("/", at: 1) {
                isLineComment = true
                index += 1
            } else if language != .python, character == "/", matches("*", at: 1) {
                blockCommentDepth = 1
                index += 1
            } else if character == "\"" || character == "'" || (language == .javascript && character == "`") {
                quote = character
                isTripleQuote = (language == .python || language == .swift)
                    && matches(character, at: 1) && matches(character, at: 2)
                lastCode = character
                if isTripleQuote { index += 2 }
            } else if !character.isWhitespace {
                lastCode = character
            }
            index += 1
        }

        guard quote == nil, blockCommentDepth == 0 else { return nil }
        return lastCode
    }
}
