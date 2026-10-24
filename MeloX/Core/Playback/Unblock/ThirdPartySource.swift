import Foundation
import Observation

/// 第三方解锁音源配置。
///
/// 改写自 Beans Music（XIaodou0416/Beans-Music，MIT 协议）UnblockSourceStore.swift
/// 的 ThirdPartySource。
/// kind：音源类型标识，用于兼容不同导入格式。
/// template：请求 URL 模板，支持 {id}、{source}、{quality} 等占位符。
/// headers：可选的请求头与内置元数据（source / qualities / apiKeys / apiKey 等）。
/// quality：默认音质选择。
/// script：LX / Baka 风格 JS 脚本内容。
///
/// 本 App 不内置任何音源与密钥：这里只保存用户自己导入的配置。
struct ThirdPartySource: Identifiable, Codable, Hashable, Sendable {
    var id = UUID().uuidString
    var name: String
    var kind: String = "keyword"
    var template: String
    var urlPath: String = "url"
    var headers: [String: String] = [:]
    var quality: String = "320k"
    var script: String?
    var enabled: Bool = true

    enum CodingKeys: String, CodingKey {
        case id, name, kind, template, urlPath, headers, quality, script, enabled
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        kind: String = "keyword",
        template: String,
        urlPath: String = "url",
        headers: [String: String] = [:],
        quality: String = "320k",
        script: String? = nil,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.template = template
        self.urlPath = urlPath
        self.headers = headers
        self.quality = quality
        self.script = script
        self.enabled = enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? L10n.string("ui.unblock.import.untitled")
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "keyword"
        template = try container.decodeIfPresent(String.self, forKey: .template) ?? ""
        urlPath = try container.decodeIfPresent(String.self, forKey: .urlPath) ?? "url"
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
        quality = try container.decodeIfPresent(String.self, forKey: .quality) ?? headers["quality"] ?? "320k"
        script = try container.decodeIfPresent(String.self, forKey: .script)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

/// 第三方音源管理：只保存用户导入的音源配置，存在本机 UserDefaults。
@MainActor
@Observable
final class ThirdPartySourceStore {
    static let shared = ThirdPartySourceStore()

    private static let storageKey = "melox.thirdPartySources"

    var sources: [ThirdPartySource] {
        didSet { save() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let list = try? JSONDecoder().decode([ThirdPartySource].self, from: data) {
            var seen = Set<String>()
            sources = list.filter { seen.insert($0.id).inserted }
        } else {
            sources = []
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func addSource(_ source: ThirdPartySource) {
        upsert(source)
    }

    func addSources(_ newSources: [ThirdPartySource]) {
        guard !newSources.isEmpty else { return }
        var merged = sources
        for source in newSources {
            if let index = merged.firstIndex(where: { $0.id == source.id }) {
                merged[index] = source
            } else {
                merged.append(source)
            }
        }
        sources = merged
        save()
    }

    func upsert(_ source: ThirdPartySource) {
        var merged = sources
        if let index = merged.firstIndex(where: { $0.id == source.id }) {
            merged[index] = source
        } else {
            merged.append(source)
        }
        sources = merged
        save()
    }

    @discardableResult
    func removeSource(id: String) -> Bool {
        let originalCount = sources.count
        sources.removeAll { $0.id == id }
        save()
        return sources.count != originalCount
    }

    func updateEnabled(id: String, enabled: Bool) {
        guard let index = sources.firstIndex(where: { $0.id == id }) else { return }
        var updated = sources
        updated[index].enabled = enabled
        sources = updated
        save()
    }
}

extension ThirdPartySourceStore {
    /// 该音源可用的音质档位：优先用音源声明的档位表，否则按平台代号取支持表。
    static func supportedQualities(
        for source: ThirdPartySource,
        providerCode: String? = nil
    ) -> [ThirdPartyAudioQuality] {
        let explicit = explicitQualities(
            from: source.headers["qualities"] ?? source.headers["qualityOptions"] ?? source.headers["qualitys"]
        )
        if !explicit.isEmpty {
            if let providerCode {
                let platform = Set(ThirdPartyAudioQuality.supported(providerCode: providerCode))
                return explicit.filter { platform.contains($0) }
            }
            return explicit
        }

        if let script = source.script,
           let explicit = scriptQualities(from: script),
           !explicit.isEmpty {
            if let providerCode {
                let platform = Set(ThirdPartyAudioQuality.supported(providerCode: providerCode))
                return explicit.filter { platform.contains($0) }
            }
            return explicit
        }

        if let providerCode {
            return ThirdPartyAudioQuality.supported(providerCode: providerCode)
        }

        if let sourceProvider = source.headers["source"] ?? source.headers["platform"] {
            return ThirdPartyAudioQuality.supported(providerCode: sourceProvider)
        }

        return ThirdPartyAudioQuality.allCases
    }

    private static func explicitQualities(from raw: String?) -> [ThirdPartyAudioQuality] {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return [] }
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;|/[]\"'"))
        return raw
            .components(separatedBy: separators)
            .compactMap { ThirdPartyAudioQuality(sourceValue: $0) }
            .uniquePreservingOrder()
    }

    private static func scriptQualities(from script: String) -> [ThirdPartyAudioQuality]? {
        let pattern = #"(?i)(?:qualitys?|qualityOptions)\s*[:=]\s*\[([^\]]*)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: script,
                options: [],
                range: NSRange(script.startIndex..<script.endIndex, in: script)
              ),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: script) else {
            return nil
        }
        return explicitQualities(from: String(script[range]))
    }
}

private extension Array where Element: Hashable {
    func uniquePreservingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
