#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Structured logical lines, not archived platform-specific rich text.
struct RuledTextContent: Codable, Equatable {
    struct Line: Codable, Equatable {
        var text: String
        var size: RuledTextSize
    }

    var version = 1
    var lines: [Line] = [Line(text: "", size: .body)]

    init() {}

    init(snapshot: RuledEditSnapshot) {
        let parts = snapshot.text.string.components(separatedBy: "\n")
        var offset = 0
        lines = parts.map { part in
            let size: RuledTextSize
            if offset < snapshot.text.length {
                size = RuledTextSize.matching(snapshot.text.attribute(.font, at: offset, effectiveRange: nil) as? RuledFont)
            } else {
                size = snapshot.trailingSize
            }
            offset += (part as NSString).length + 1
            return Line(text: part, size: size)
        }
    }

    func snapshot(document: RuledPageDocument) -> RuledEditSnapshot {
        let text = NSMutableAttributedString(string: "")
        for (index, line) in lines.enumerated() {
            text.append(NSAttributedString(
                string: line.text + (index < lines.count - 1 ? "\n" : ""),
                attributes: line.size.attributes(for: document)
            ))
        }
        return RuledEditSnapshot(text: text, selection: NSRange(location: 0, length: 0), typingSize: lines.first?.size ?? .body,
                                 trailingSize: lines.last?.size ?? .body)
    }

    static func decode(_ data: Data) throws -> RuledTextContent {
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.version == 1, !value.lines.isEmpty,
              value.lines.allSatisfy({ !$0.text.contains("\n") }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return value
    }

    func encoded() throws -> Data { try JSONEncoder().encode(self) }
}

struct RuledEditSnapshot {
    var text: NSAttributedString
    var selection: NSRange
    var typingSize: RuledTextSize
    var trailingSize: RuledTextSize = .body
}

/// Both native editors use these transformations and the same TextKit layout policy.
enum RuledTextCommands {
    static func currentSize(_ state: RuledEditSnapshot) -> RuledTextSize {
        if state.selection.location < state.text.length {
            return RuledTextSize.matching(state.text.attribute(.font, at: state.selection.location, effectiveRange: nil) as? RuledFont)
        }
        return state.typingSize
    }

    static func resize(_ state: RuledEditSnapshot, to size: RuledTextSize, document: RuledPageDocument) -> RuledEditSnapshot {
        let text = NSMutableAttributedString(attributedString: state.text)
        // A command affects the logical line at the caret, never the next selected paragraph.
        let range = (text.string as NSString).paragraphRange(for: NSRange(location: state.selection.location, length: 0))
        text.addAttributes(size.attributes(for: document), range: range)
        var result = state
        result.text = text
        result.typingSize = size
        if range.location == text.length { result.trailingSize = size }
        return result
    }

    static func enlarged(_ state: RuledEditSnapshot, document: RuledPageDocument) -> RuledEditSnapshot {
        let size = RuledTextSize(rawValue: min(3, currentSize(state).rawValue + 1)) ?? .largeHeading
        return resize(state, to: size, document: document)
    }

    static func insertingReturn(_ state: RuledEditSnapshot, document: RuledPageDocument) -> RuledEditSnapshot {
        let text = NSMutableAttributedString(attributedString: state.text)
        text.replaceCharacters(in: state.selection, with: NSAttributedString(
            string: "\n", attributes: currentSize(state).attributes(for: document)
        ))
        let cursor = state.selection.location + 1
        let nextLine = (text.string as NSString).paragraphRange(for: NSRange(location: cursor, length: 0))
        text.addAttributes(RuledTextSize.body.attributes(for: document), range: nextLine)
        return RuledEditSnapshot(text: text, selection: NSRange(location: cursor, length: 0), typingSize: .body,
                                 trailingSize: cursor == text.length ? .body : state.trailingSize)
    }
}
