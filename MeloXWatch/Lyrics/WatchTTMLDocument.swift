import Foundation

nonisolated final class WatchTTMLNode {
    enum Content {
        case text(String)
        case child(WatchTTMLNode)
    }

    let name: String
    let attributes: [String: String]
    var contents: [Content] = []

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }

    var localName: String {
        name.split(separator: ":").last.map(String.init) ?? name
    }

    var children: [WatchTTMLNode] {
        contents.compactMap {
            guard case .child(let node) = $0 else { return nil }
            return node
        }
    }

    func attribute(_ requestedName: String) -> String? {
        attributes[requestedName] ?? attributes.first {
            $0.key.split(separator: ":").last.map(String.init)
                == requestedName
        }?.value
    }

    func hasRole(_ role: String) -> Bool {
        attributes.contains {
            $0.key.split(separator: ":").last == "role"
                && $0.value == role
        }
    }

    func descendants(
        where predicate: (WatchTTMLNode) -> Bool
    ) -> [WatchTTMLNode] {
        var result = predicate(self) ? [self] : []
        for child in children {
            result.append(contentsOf: child.descendants(where: predicate))
        }
        return result
    }

    func text(excludingRoles: Set<String> = []) -> String {
        if excludingRoles.contains(where: hasRole) {
            return ""
        }
        return contents.map { content in
            switch content {
            case .text(let text): text
            case .child(let child):
                child.text(excludingRoles: excludingRoles)
            }
        }.joined()
    }
}

nonisolated enum WatchTTMLDocument {
    static func parse(_ source: String) -> WatchTTMLNode? {
        guard let data = source.data(using: .utf8) else { return nil }
        let builder = WatchTTMLDocumentBuilder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = true
        return parser.parse() ? builder.root : nil
    }
}

nonisolated private final class WatchTTMLDocumentBuilder:
    NSObject,
    XMLParserDelegate
{
    private(set) var root: WatchTTMLNode?
    private var stack: [WatchTTMLNode] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let node = WatchTTMLNode(
            name: qName ?? elementName,
            attributes: attributeDict
        )
        if let parent = stack.last {
            parent.contents.append(.child(node))
        } else {
            root = node
        }
        stack.append(node)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let node = stack.last else { return }
        if case .text(let existing)? = node.contents.last {
            node.contents[node.contents.count - 1] = .text(existing + string)
        } else {
            node.contents.append(.text(string))
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        _ = stack.popLast()
    }
}
