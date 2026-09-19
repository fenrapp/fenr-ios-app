import Foundation

extension GPXRouteParser {
    // Repair only free text. Markup, attributes, entities and route measurements remain untouched.
    func recoveringText(in data: Data, maximumBytes: Int) -> Data? {
        guard let source = String(data: data, encoding: .utf8) else { return nil }
        var remaining = source[...]
        var result = Data()
        var textElement: String?
        var didRecover = false

        while !remaining.isEmpty {
            let chunk: Substring
            if remaining.first == "<" {
                guard let markup = markupPrefix(in: remaining) else { return nil }
                chunk = markup
                if !markup.hasPrefix("<!"), !markup.hasPrefix("<?") {
                    textElement = recoverableElement(in: markup)
                }
                guard result.count + chunk.utf8.count <= maximumBytes else { return nil }
                result.append(contentsOf: chunk.utf8)
            } else {
                chunk = remaining.prefix { $0 != "<" }
                let text = String(chunk)
                // Preserve reference-shaped tokens, including unknown or invalid entities,
                // so the XML parser still rejects ambiguous or unsupported references.
                let recovered = textElement == nil ? text : text.replacingOccurrences(
                    of: #"&(?!(?:[^\s<&;]*);)"#,
                    with: "&amp;",
                    options: .regularExpression
                )
                didRecover = didRecover || recovered != text
                guard result.count + recovered.utf8.count <= maximumBytes else { return nil }
                result.append(contentsOf: recovered.utf8)
            }
            remaining = remaining[chunk.endIndex...]
        }
        return didRecover ? result : nil
    }

    private func markupPrefix(in text: Substring) -> Substring? {
        let terminator: String?
        if text.hasPrefix("<!--") {
            terminator = "-->"
        } else if text.hasPrefix("<![CDATA[") {
            terminator = "]]>"
        } else if text.hasPrefix("<?") {
            terminator = "?>"
        } else {
            terminator = nil
        }
        if let terminator {
            guard let end = text.range(of: terminator) else { return nil }
            return text[..<end.upperBound]
        }
        // Declarations can contain nested markup and entity definitions. Never repair them.
        guard !text.hasPrefix("<!") else { return nil }
        var quote: Character?
        for index in text.indices.dropFirst() {
            let character = text[index]
            if let delimiter = quote {
                if character == delimiter { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ">" {
                return text[...index]
            }
        }
        return nil
    }

    private func recoverableElement(in markup: Substring) -> String? {
        guard !markup.hasPrefix("</"), !markup.hasSuffix("/>") else { return nil }
        let name = markup.dropFirst().prefix { !$0.isWhitespace && $0 != ">" && $0 != "/" }
        switch name {
        case "name", "desc", "cmt", "src": return String(name)
        default: return nil
        }
    }
}
