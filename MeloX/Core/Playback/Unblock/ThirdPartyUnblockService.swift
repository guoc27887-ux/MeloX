import Foundation
import os.log

/// 第三方音源解锁服务：官方地址拿不到、或仅为试听片段时，从用户导入的
/// 第三方音源解析可播地址。
///
/// 改写自 Beans Music（XIaodou0416/Beans-Music，MIT 协议）UnblockService.swift：
/// 并发抢答、模板占位符、密钥池、音质降级链、QQ CDN 节点兜底均与 Beans 一致，
/// 仅把 BeansLogger 换成系统 Logger、UA 换成 MeloX 自己的标识。
/// 本服务不内置任何音源与密钥：没有用户导入的音源时直接返回 nil。
enum ThirdPartyUnblockService {
    /// 当前播放歌曲所属平台（MeloX 的歌曲均来自网易云；QQ / 酷狗 ID 位留作扩展）。
    enum Provider: String, Sendable {
        case netease = "wy"
        case qq = "tx"
        case kugou = "kg"
    }

    struct Resolved: Sendable {
        let url: URL
        let source: String
        let quality: ThirdPartyAudioQuality

        init(url: URL, source: String, quality: ThirdPartyAudioQuality = .kb320) {
            self.url = url
            self.source = source
            self.quality = quality
        }
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 7
        config.timeoutIntervalForResource = 12
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MeloX",
        category: "ThirdPartyUnblock"
    )

    /// 入口：并发尝试用户导入且可用于当前平台的音源，返回第一个可用地址。
    static func resolve(
        name: String,
        artists: String,
        neteaseID: Int,
        songSource: Provider = .netease,
        qqMid: String? = nil,
        qqMediaMid: String? = nil,
        kugouID: String? = nil,
        preferredQuality: ThirdPartyAudioQuality = .kb320,
        excludedHosts: Set<String> = []
    ) async -> Resolved? {
        let hasSongIdentity = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !artists.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasSongIdentity else { return nil }
        let sources = await MainActor.run { ThirdPartySourceStore.shared.sources }
            .filter { source in
                guard source.enabled else { return false }
                return isScriptSource(source)
                    || canUse(source: source, songSource: songSource, neteaseID: neteaseID, qqMid: qqMid, kugouID: kugouID)
            }
        guard !sources.isEmpty else { return nil }

        return await resolveSources(
            sources,
            name: name,
            artists: artists,
            neteaseID: neteaseID,
            songSource: songSource,
            qqMid: qqMid,
            qqMediaMid: qqMediaMid,
            kugouID: kugouID,
            preferredQuality: preferredQuality,
            excludedHosts: excludedHosts
        )
    }

    private static func resolveSources(
        _ sources: [ThirdPartySource],
        name: String,
        artists: String,
        neteaseID: Int,
        songSource: Provider,
        qqMid: String?,
        qqMediaMid: String?,
        kugouID: String?,
        preferredQuality: ThirdPartyAudioQuality,
        excludedHosts: Set<String>
    ) async -> Resolved? {
        guard !sources.isEmpty else { return nil }

        // 相同配置只保留每个请求指纹的第一个，避免重复请求同一个服务。
        var seen = Set<String>()
        let uniqueSources = sources.filter { seen.insert(requestFingerprint(for: $0)).inserted }

        // 慢源/失效源不要拖住播放：全部候选一起请求，最快命中的播放地址直接返回。
        return await withTaskGroup(of: Resolved?.self) { group in
            for source in uniqueSources {
                group.addTask {
                    if isScriptSource(source) {
                        return await scriptSourceRequest(
                            source: source,
                            name: name,
                            artists: artists,
                            neteaseID: neteaseID,
                            songSource: songSource,
                            qqMid: qqMid,
                            qqMediaMid: qqMediaMid,
                            kugouID: kugouID,
                            preferredQuality: preferredQuality,
                            excludedHosts: excludedHosts
                        )
                    }
                    return await presetSourceRequest(
                        source: source,
                        name: name,
                        artists: artists,
                        neteaseID: neteaseID,
                        songSource: songSource,
                        qqMid: qqMid,
                        qqMediaMid: qqMediaMid,
                        kugouID: kugouID,
                        preferredQuality: preferredQuality,
                        excludedHosts: excludedHosts
                    )
                }
            }
            for await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }
            return nil
        }
    }

    private static func canUse(source: ThirdPartySource, songSource: Provider, neteaseID: Int, qqMid: String?, kugouID: String?) -> Bool {
        let expectedProvider = songSource.rawValue
        if let provider = source.headers["source"], !provider.isEmpty, provider != expectedProvider {
            return false
        }
        if songSource == .qq {
            return qqMid?.isEmpty == false
        }
        if songSource == .kugou {
            return kugouID?.isEmpty == false
        }
        return neteaseID > 0
    }

    private static func isScriptSource(_ source: ThirdPartySource) -> Bool {
        let kind = source.kind.lowercased()
        return kind.contains("script") || source.script?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private static func presetSourceRequest(
        source: ThirdPartySource,
        name: String,
        artists: String,
        neteaseID: Int,
        songSource: Provider,
        qqMid: String?,
        qqMediaMid: String?,
        kugouID: String?,
        preferredQuality: ThirdPartyAudioQuality,
        excludedHosts: Set<String>
    ) async -> Resolved? {
        guard !source.template.isEmpty else { return nil }
        let expectedProvider = songSource.rawValue
        if let provider = source.headers["source"], !provider.isEmpty, provider != expectedProvider {
            return nil
        }
        let songIDs: [String]
        switch songSource {
        case .netease where neteaseID > 0:
            songIDs = [String(neteaseID)]
        case .qq:
            guard let qqMid, !qqMid.isEmpty else { return nil }
            songIDs = qqIDCandidates(songID: neteaseID, songMid: qqMid, mediaMid: qqMediaMid)
        case .kugou:
            guard let kugouID, !kugouID.isEmpty else { return nil }
            songIDs = [kugouID]
        default:
            return nil
        }
        let apiKeys = orderedAPIKeys(for: source)
        let apiKeyPlaceholders = ["{apiKey}", "{apikey}", "{key}"]
        let requiresAPIKey = apiKeyPlaceholders.contains { source.template.contains($0) }
        if requiresAPIKey && apiKeys.isEmpty {
            logger.debug("Third-party source skipped (no key): \(source.name, privacy: .private)")
            return nil
        }
        for (idIndex, songID) in songIDs.enumerated() {
            var baseURLString = source.template
            let idValues: [String: String] = [
                "{id}": songID,
                "{songId}": songID,
                "{songid}": songID,
                "{songID}": songID,
                "{songmid}": qqMid ?? songID,
                "{mid}": qqMid ?? songID,
                "{hash}": kugouID ?? songID
            ]
            for (placeholder, value) in idValues {
                baseURLString = baseURLString.replacingOccurrences(of: placeholder, with: value)
            }
            baseURLString = baseURLString.replacingOccurrences(of: "{source}", with: expectedProvider)
            baseURLString = baseURLString.replacingOccurrences(of: "{name}", with: urlEncoded(name))
            let keyword = ([name, artists].filter { !$0.isEmpty }).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            baseURLString = baseURLString.replacingOccurrences(of: "{keyword}", with: urlEncoded(keyword))
            baseURLString = baseURLString.replacingOccurrences(of: "{artist}", with: urlEncoded(artists))
            for qualityValue in qualityCandidates(for: source, songSource: songSource, preferredQuality: preferredQuality) {
                let urlString = replacingQualityPlaceholders(in: baseURLString, with: qualityValue)
                let idLabel = songSource == .qq && songIDs.count > 1 ? " ID=\(idIndex + 1)/\(songIDs.count)" : ""
                if !apiKeys.isEmpty {
                    for (originalIndex, apiKey) in apiKeys {
                        let keyedURLString = apiKeyPlaceholders.reduce(urlString) { result, placeholder in
                            result.replacingOccurrences(of: placeholder, with: urlEncoded(apiKey))
                        }
                        guard let url = URL(string: keyedURLString) else { continue }
                        if let resolved = await presetSourceRequestOnce(
                            source: source,
                            url: url,
                            apiKey: apiKey,
                            keyIndex: originalIndex + 1,
                            keyTotal: apiKeys.count,
                            quality: qualityValue,
                            idLabel: idLabel,
                            excludedHosts: excludedHosts
                        ) {
                            rememberWorkingKey(originalIndex, for: source)
                            return resolved
                        }
                    }
                } else if !requiresAPIKey,
                          let url = URL(string: urlString),
                          let resolved = await presetSourceRequestOnce(
                    source: source,
                    url: url,
                    apiKey: nil,
                    keyIndex: 0,
                    keyTotal: 0,
                    quality: qualityValue,
                    idLabel: idLabel,
                    excludedHosts: excludedHosts
                ) {
                    return resolved
                }
            }
        }

        if !apiKeys.isEmpty {
            logger.debug("Third-party source keys all missed: \(source.name, privacy: .private) (\(apiKeys.count) keys)")
        }
        return nil
    }

    private static func scriptSourceRequest(
        source: ThirdPartySource,
        name: String,
        artists: String,
        neteaseID: Int,
        songSource: Provider,
        qqMid: String?,
        qqMediaMid: String?,
        kugouID: String?,
        preferredQuality: ThirdPartyAudioQuality,
        excludedHosts: Set<String>
    ) async -> Resolved? {
        guard let script = source.script?.trimmingCharacters(in: .whitespacesAndNewlines), !script.isEmpty else { return nil }
        let songIDs: [String]
        switch songSource {
        case .netease where neteaseID > 0:
            songIDs = [String(neteaseID)]
        case .qq:
            guard let qqMid, !qqMid.isEmpty else { return nil }
            var candidates: [String] = [qqMid]
            if let qqMediaMid, !qqMediaMid.isEmpty {
                candidates.append(qqMediaMid)
            }
            if neteaseID > 0 {
                candidates.append(String(neteaseID))
            }
            var seen = Set<String>()
            songIDs = candidates.filter { seen.insert($0).inserted }
        case .kugou:
            guard let kugouID, !kugouID.isEmpty else { return nil }
            songIDs = [kugouID]
        default:
            return nil
        }

        let qualities = qualityCandidates(for: source, songSource: songSource, preferredQuality: preferredQuality)
        for songID in songIDs {
            for qualityValue in qualities {
                if let resolved = await MeloXScriptSourceRunner.shared.resolve(
                    source: source,
                    script: script,
                    songSource: songSource,
                    songID: songID,
                    qqMid: qqMid,
                    qqMediaMid: qqMediaMid,
                    kugouID: kugouID,
                    name: name,
                    artists: artists,
                    quality: qualityValue,
                    excludedHosts: excludedHosts
                ) {
                    logger.info("Script source hit: \(source.name, privacy: .private) quality=\(qualityValue, privacy: .private)")
                    return resolved
                }
            }
        }
        return nil
    }

    private static func presetSourceRequestOnce(
        source: ThirdPartySource,
        url: URL,
        apiKey: String?,
        keyIndex: Int,
        keyTotal: Int,
        quality: String,
        idLabel: String = "",
        excludedHosts: Set<String>
    ) async -> Resolved? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 7
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MeloX-ThirdPartySource/1.0", forHTTPHeaderField: "User-Agent")
        if let apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        let keyLabel = idLabel + (keyTotal > 1 ? " key=\(keyIndex)/\(keyTotal)" : "") + " quality=\(quality)"
        let metadataKeys: Set<String> = [
            "source", "quality", "qualities", "qualityOptions", "qualitys",
            "br", "level", "apiKey", "apiKeys", "apiKeyQuery"
        ]
        for (key, value) in source.headers where !metadataKeys.contains(key) {
            let resolvedValue = value
                .replacingOccurrences(of: "{quality}", with: quality)
                .replacingOccurrences(of: "{source}", with: source.headers["source"] ?? "")
            request.setValue(resolvedValue, forHTTPHeaderField: key)
        }
        request.setValue(quality, forHTTPHeaderField: "quality")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.debug("Third-party source request failed: \(source.name, privacy: .private)\(keyLabel, privacy: .private) \(error.localizedDescription, privacy: .private)")
            return nil
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            logger.debug("Third-party source HTTP failed: \(source.name, privacy: .private)\(keyLabel, privacy: .private) status=\(status)")
            return nil
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.debug("Third-party source bad response format: \(source.name, privacy: .private)\(keyLabel, privacy: .private)")
            return nil
        }
        if let code = responseCode(from: obj), code != 0 && code != 200 {
            let message = obj["message"] as? String ?? obj["msg"] as? String ?? "code=\(code)"
            logger.debug("Third-party source returned failure: \(source.name, privacy: .private)\(keyLabel, privacy: .private) \(message, privacy: .private)")
            return nil
        }
        guard let value = valueAtAnyPath(obj, source.urlPath),
              let resolvedURL = value as? String, !resolvedURL.isEmpty,
              let rawPlayURL = URL(string: resolvedURL),
              let playURL = playablePlaybackURL(from: rawPlayURL, source: source, keyLabel: keyLabel, excludedHosts: excludedHosts) else {
            logger.debug("Third-party source response has no playback URL: \(source.name, privacy: .private)\(keyLabel, privacy: .private)")
            return nil
        }
        if rawPlayURL != playURL {
            logger.debug("Third-party source switched QQ CDN node: \(rawPlayURL.host ?? "?", privacy: .private) -> \(playURL.host ?? "?", privacy: .private)")
        }
        if let host = playURL.host?.lowercased(), excludedHosts.contains(host) {
            logger.debug("Third-party source skipped failed node: \(source.name, privacy: .private)\(keyLabel, privacy: .private) host=\(host, privacy: .private)")
            return nil
        }
        logger.info("Third-party source hit: \(source.name, privacy: .private)\(keyLabel, privacy: .private)")
        return Resolved(
            url: playURL,
            source: source.name,
            quality: ThirdPartyAudioQuality(sourceValue: quality) ?? .kb320
        )
    }

    /// 部分第三方接口会固定返回不稳定的 QQ CDN 节点。
    /// 不在这里做 Range 探测：部分 QQ CDN 会拒绝探测请求，但 AVPlayer
    /// 带完整请求头后仍可正常播放。实际失败由播放器反馈，再换下一个节点。
    private static func playablePlaybackURL(from rawURL: URL, source: ThirdPartySource, keyLabel: String, excludedHosts: Set<String>) -> URL? {
        let candidates = qqPlaybackURLCandidates(for: rawURL)
        for candidate in candidates {
            guard let host = candidate.host?.lowercased() else { continue }
            if excludedHosts.contains(host) {
                logger.debug("Third-party source skipped failed node: \(source.name, privacy: .private)\(keyLabel, privacy: .private) host=\(host, privacy: .private)")
                continue
            }
            if rawURL != candidate {
                logger.debug("Third-party source prepared QQ CDN fallback node: \(rawURL.host ?? "?", privacy: .private) -> \(host, privacy: .private)")
            }
            return candidate
        }
        return nil
    }

    private static func qqPlaybackURLCandidates(for url: URL) -> [URL] {
        guard let host = url.host?.lowercased(), isQQPlaybackHost(host) else {
            return [url]
        }
        let hosts = [
            host,
            "isure6.ptqqmusic.gitv.tv",
            "isure.stream.qqmusic.qq.com",
            "dl.stream.qqmusic.qq.com",
            "ws.stream.qqmusic.qq.com",
            "streamoc.music.tc.qq.com"
        ]
        var seen = Set<String>()
        return hosts.compactMap { replacement in
            guard seen.insert(replacement).inserted else { return nil }
            return replacingHost(of: url, with: replacement)
        }
    }

    private static func replacingHost(of url: URL, with replacementHost: String) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.host = replacementHost
        return components?.url ?? url
    }

    private static func isQQPlaybackHost(_ host: String) -> Bool {
        host.contains("qq.com") || host.contains("qqmusic") || host.contains("ptqqmusic") || host.contains("gitv.tv")
    }

    private static func replacingQualityPlaceholders(in template: String, with quality: String) -> String {
        ["{quality}", "{br}", "{level}"].reduce(template) { result, placeholder in
            result.replacingOccurrences(of: placeholder, with: quality)
        }
    }

    private static func qualityCandidates(for source: ThirdPartySource, songSource: Provider, preferredQuality: ThirdPartyAudioQuality) -> [String] {
        let provider = songSource.rawValue
        let supported = Set(ThirdPartySourceStore.supportedQualities(for: source, providerCode: provider))
        let platformSupported = Set(ThirdPartyAudioQuality.supported(providerCode: provider))
        let sourceDefault = ThirdPartyAudioQuality(sourceValue: source.quality)
        let platformDefault: ThirdPartyAudioQuality = .kb320

        var ordered: [ThirdPartyAudioQuality] = []
        ordered.append(contentsOf: preferredQuality.fallbackChain)
        if let sourceDefault, sourceDefault != preferredQuality {
            ordered.append(contentsOf: sourceDefault.fallbackChain)
        }
        if platformDefault != preferredQuality && platformDefault != sourceDefault {
            ordered.append(contentsOf: platformDefault.fallbackChain)
        }

        let filtered = ordered.filter {
            platformSupported.contains($0) && (supported.isEmpty || supported.contains($0))
        }
        var seen = Set<String>()
        let result = filtered.compactMap { quality -> String? in
            let trimmed = quality.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || !seen.insert(trimmed).inserted ? nil : trimmed
        }
        if !result.isEmpty { return result }

        // 若源只声明了非标准档位，至少尝试它声明过的档位，不能越过能力表强行请求未知音质。
        if !supported.isEmpty {
            return ThirdPartySourceStore
                .supportedQualities(for: source, providerCode: provider)
                .map(\.rawValue)
        }

        var fallbackSeen = Set<String>()
        return ordered.compactMap { quality -> String? in
            let trimmed = quality.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || !fallbackSeen.insert(trimmed).inserted ? nil : trimmed
        }
    }

    private static func qqIDCandidates(songID: Int, songMid: String, mediaMid: String?) -> [String] {
        var seen = Set<String>()
        let numericID = songID > 0 ? String(songID) : nil
        return [numericID, mediaMid, songMid].compactMap { raw in
            guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty,
                  seen.insert(value).inserted else { return nil }
            return value
        }
    }

    private static func requestFingerprint(for source: ThirdPartySource) -> String {
        let headers = source.headers
            .filter { $0.key != "source" }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        let scriptFingerprint = source.script?.hashValue.description ?? ""
        return "\(source.template)|\(source.urlPath)|\(headers)|\(source.quality)|\(scriptFingerprint)"
    }

    private static func sourceAPIKeys(for source: ThirdPartySource) -> [String] {
        var keys: [String] = []
        if let raw = source.headers["apiKeys"], !raw.isEmpty {
            keys.append(contentsOf: raw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
        }
        if let raw = source.headers["apiKey"]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            keys.append(raw)
        }
        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }

    private static func orderedAPIKeys(for source: ThirdPartySource) -> [(Int, String)] {
        let keys = sourceAPIKeys(for: source)
        var seen = Set<String>()
        let unique = keys.enumerated().compactMap { index, key -> (Int, String)? in
            seen.insert(key).inserted ? (index, key) : nil
        }
        let preferred = UserDefaults.standard.integer(forKey: preferredKeyIndexDefaultsKey(for: source))
        guard let hit = unique.firstIndex(where: { $0.0 == preferred }), hit > 0 else {
            return unique
        }
        var reordered = unique
        let item = reordered.remove(at: hit)
        reordered.insert(item, at: 0)
        return reordered
    }

    private static func rememberWorkingKey(_ index: Int, for source: ThirdPartySource) {
        UserDefaults.standard.set(index, forKey: preferredKeyIndexDefaultsKey(for: source))
    }

    private static func preferredKeyIndexDefaultsKey(for source: ThirdPartySource) -> String {
        "melox.unblock.preferredKeyIndex.\(source.id)"
    }

    private static func responseCode(from object: [String: Any]) -> Int? {
        if let code = object["code"] as? Int {
            return code
        }
        if let code = object["code"] as? NSNumber {
            return code.intValue
        }
        if let code = object["code"] as? String {
            return Int(code)
        }
        return nil
    }

    /// 多个点分路径取值：data.music|data.url|url。
    private static func valueAtAnyPath(_ obj: Any, _ paths: String) -> Any? {
        for path in paths.split(separator: "|") {
            if let value = valueAtPath(obj, String(path)) {
                return value
            }
        }
        return nil
    }

    /// 点分路径取值：url / data.url / data.audioUrl ...
    private static func valueAtPath(_ obj: Any, _ path: String) -> Any? {
        var current: Any = obj
        for key in path.split(separator: ".") {
            if let dict = current as? [String: Any], let next = dict[String(key)] {
                current = next
            } else if let dict = current as? NSDictionary, let next = dict[String(key)] {
                current = next
            } else {
                return nil
            }
        }
        return current
    }

    private static func urlEncoded(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}
