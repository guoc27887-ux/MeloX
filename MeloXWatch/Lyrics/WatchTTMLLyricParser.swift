import Foundation

nonisolated enum WatchTTMLLyricParser {
    static func parse(_ source: String) -> [WatchLyricLine] {
        guard let root = WatchTTMLDocument.parse(source) else { return [] }
        let secondaryAgents = secondaryAgentIdentifiers(in: root)
        let translations = auxiliaryTracks(named: "translation", in: root)
        let romanizations = auxiliaryTracks(
            named: "transliteration",
            in: root
        )
        return root.descendants { $0.localName == "p" }
            .compactMap {
                parseLine(
                    $0,
                    secondaryAgents: secondaryAgents,
                    translations: translations,
                    romanizations: romanizations
                )
            }
            .sorted { $0.time < $1.time }
    }

    private static func parseLine(
        _ node: WatchTTMLNode,
        secondaryAgents: Set<String>,
        translations: [String: WatchAuxiliaryLyric],
        romanizations: [String: WatchAuxiliaryLyric]
    ) -> WatchLyricLine? {
        guard let start = parseTime(node.attribute("begin")),
              let end = parseTime(node.attribute("end")),
              end >= start else {
            return nil
        }
        let syllables = timedSpans(in: node)
        let rawText = syllables.isEmpty
            ? node.text(
                excludingRoles: ["x-translation", "x-roman", "x-bg"]
            )
            : syllables.map(\.text).joined()
        guard let text = normalized(rawText) else { return nil }

        let key = node.attribute("key")
        let inlineTranslation = roleText("x-translation", in: node)
        let inlineRomanization = roleText("x-roman", in: node)
        let trackedRomanization = key.flatMap { romanizations[$0] }

        return WatchLyricLine(
            time: start,
            duration: end - start,
            text: text,
            syllables: syllables,
            romanization: normalized(
                inlineRomanization ?? trackedRomanization?.text
            ),
            romanizationSyllables:
                trackedRomanization?.syllables ?? [],
            translation: normalized(
                inlineTranslation ?? key.flatMap { translations[$0]?.text }
            ),
            backgroundVocal: backgroundVocal(
                in: node,
                parentStart: start,
                parentEnd: end
            ),
            isSecondaryVocal: node.attribute("agent").map {
                secondaryAgents.contains($0)
            }
        )
    }

    private static func secondaryAgentIdentifiers(
        in root: WatchTTMLNode
    ) -> Set<String> {
        var primaryPersonIdentifier: String?
        var result: Set<String> = []
        for node in root.descendants(where: { $0.localName == "agent" }) {
            guard let identifier = node.attribute("id") else { continue }
            if node.attribute("type")?.lowercased() == "group" {
                continue
            }
            if primaryPersonIdentifier == nil {
                primaryPersonIdentifier = identifier
            } else {
                result.insert(identifier)
            }
        }
        return result
    }

    private static func backgroundVocal(
        in node: WatchTTMLNode,
        parentStart: TimeInterval,
        parentEnd: TimeInterval
    ) -> WatchBackgroundVocal? {
        let entries = node.contents.enumerated().compactMap {
            index,
            content -> (index: Int, node: WatchTTMLNode)? in
            guard case .child(let child) = content,
                  child.localName == "span",
                  child.hasRole("x-bg") else {
                return nil
            }
            return (index, child)
        }
        guard let firstEntry = entries.first else { return nil }
        let syllables = entries.flatMap { timedSpans(in: $0.node) }
        let rawText = syllables.isEmpty
            ? entries.map {
                $0.node.text(
                    excludingRoles: ["x-translation", "x-roman"]
                )
            }.joined()
            : syllables.map(\.text).joined()
        guard let text = normalized(rawText) else { return nil }

        let start = entries.compactMap {
            parseTime($0.node.attribute("begin"))
        }.min() ?? syllables.first?.startTime ?? parentStart
        let end = entries.compactMap {
            parseTime($0.node.attribute("end"))
        }.max() ?? syllables.last?.endTime ?? parentEnd
        let firstPrimaryIndex = node.contents.firstIndex { content in
            guard case .child(let child) = content,
                  child.localName == "span" else {
                return false
            }
            return !child.hasRole("x-translation")
                && !child.hasRole("x-roman")
                && !child.hasRole("x-bg")
        }
        let position: WatchBackgroundVocalsPosition =
            if let firstPrimaryIndex,
               firstEntry.index < firstPrimaryIndex {
                .beforePrimary
            } else {
                .afterPrimary
            }

        return WatchBackgroundVocal(
            time: start,
            duration: max(end - start, 0),
            text: text,
            syllables: syllables,
            translation: entries.compactMap {
                roleText("x-translation", in: $0.node)
            }.first,
            position: position
        )
    }

    private static func auxiliaryTracks(
        named name: String,
        in root: WatchTTMLNode
    ) -> [String: WatchAuxiliaryLyric] {
        var result: [String: WatchAuxiliaryLyric] = [:]
        for container in root.descendants(where: { $0.localName == name }) {
            for node in container.descendants(where: {
                $0.localName == "text"
            }) {
                guard let key = node.attribute("for"),
                      result[key] == nil else {
                    continue
                }
                let syllables = timedSpans(in: node)
                let rawText = syllables.isEmpty
                    ? node.text(excludingRoles: ["x-bg"])
                    : syllables.map(\.text).joined()
                guard let text = normalized(rawText) else { continue }
                result[key] = WatchAuxiliaryLyric(
                    text: text,
                    syllables: syllables
                )
            }
        }
        return result
    }

    private static func timedSpans(
        in parent: WatchTTMLNode
    ) -> [WatchLyricSyllable] {
        var result: [WatchLyricSyllable] = []
        for index in parent.contents.indices {
            guard case .child(let span) = parent.contents[index],
                  span.localName == "span",
                  !span.hasRole("x-translation"),
                  !span.hasRole("x-roman"),
                  !span.hasRole("x-bg"),
                  let start = parseTime(span.attribute("begin")),
                  let end = parseTime(span.attribute("end")),
                  end >= start else {
                continue
            }
            var text = span.text(
                excludingRoles: ["x-translation", "x-roman", "x-bg"]
            )
            if index + 1 < parent.contents.count,
               case .text(let separator) = parent.contents[index + 1],
               !separator.contains("\n"),
               separator.allSatisfy(\.isWhitespace) {
                text += separator
            }
            guard !text.isEmpty else { continue }
            result.append(
                WatchLyricSyllable(
                    text: text,
                    startTime: start,
                    endTime: end
                )
            )
        }
        return result
    }

    private static func roleText(
        _ role: String,
        in node: WatchTTMLNode
    ) -> String? {
        node.children.lazy
            .filter { $0.localName == "span" && $0.hasRole(role) }
            .compactMap { normalized($0.text()) }
            .first
    }

    private static func normalized(_ value: String?) -> String? {
        guard let rawValue = value else { return nil }
        let trimmedValue = rawValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static func parseTime(_ value: String?) -> TimeInterval? {
        guard let rawValue = value else { return nil }
        let trimmedValue = rawValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if trimmedValue.hasSuffix("ms"),
           let milliseconds = Double(trimmedValue.dropLast(2)) {
            return milliseconds / 1_000
        }
        if trimmedValue.hasSuffix("s"),
           let seconds = Double(trimmedValue.dropLast()) {
            return seconds
        }
        let parts = trimmedValue.split(separator: ":")
        guard let secondsPart = parts.last,
              let seconds = Double(secondsPart) else {
            return nil
        }
        if parts.count == 1 { return seconds }
        guard let minutes = Double(parts[parts.count - 2]) else {
            return nil
        }
        let hours = parts.count >= 3
            ? Double(parts[parts.count - 3]) ?? 0
            : 0
        return hours * 3_600 + minutes * 60 + seconds
    }
}

nonisolated private struct WatchAuxiliaryLyric {
    let text: String
    let syllables: [WatchLyricSyllable]
}
