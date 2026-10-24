import CryptoKit
import Foundation
import os.log

/// 灰色歌曲解锁：网易云无版权/下架/仅试听时，从第三方音源匹配可播地址。
///
/// 思路来源：kumone（missuo/kumone，LGPL-3.0-only）的 UnblockService 与
/// UnblockNeteaseMusic 的匹配策略；本文件为独立重写，未复制 kumone 原文。
/// 解析顺序与 kumone 一致：先 pyncmd（按网易云原曲 ID 直取），再按酷狗、
/// 酷我顺序做“歌名 + 首位歌手”搜索匹配。三个源均为公开的第三方接口，
/// 不需要用户额外部署服务端或代理。
///
/// 与 kumone 的一处不同：酷狗搜索改用 HTTPS。MeloX 的 Info.plist 没有配
/// ATS 例外，明文 HTTP 会被系统拦截；酷狗搜索接口本身支持 HTTPS，
/// 失败时仍会顺延到酷我，不会因此卡住播放。

struct GrayTrackResolution: Sendable {
    let source: GrayTrackSource
    let url: URL
}

enum GrayTrackUnblockError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case missingBitrate
    case missingStreamURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid gray-track source URL"
        case .invalidResponse:
            return "Invalid gray-track source response"
        case .httpStatus(let status):
            return "Gray-track source HTTP status \(status)"
        case .missingBitrate:
            return "Gray-track source response has no bitrate"
        case .missingStreamURL:
            return "Gray-track source response has no stream URL"
        }
    }
}

/// 只做第三方音源请求的 HTTP 客户端：不存 Cookie、不读缓存、单次 10 秒超时，
/// 与主站登录态完全隔离。
struct GrayTrackHTTPClient {
    static let shared = GrayTrackHTTPClient()

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        session = URLSession(configuration: configuration)
    }

    func data(
        from urlString: String,
        userAgent: String = "Mozilla/5.0"
    ) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw GrayTrackUnblockError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw GrayTrackUnblockError.httpStatus(
                (response as? HTTPURLResponse)?.statusCode ?? -1
            )
        }
        return data
    }
}

/// 第三方搜索结果与网易云曲目的匹配规则：歌名归一化后相等、时长差在
/// 5 秒内、版本标记（live/remix/伴奏/翻唱等）对称、首位歌手出现在候选
/// 歌手列表中。时长未知（0）的曲目不参与搜索匹配，只能走 pyncmd 直取。
enum GrayTrackMatcher {
    static func keyword(for song: Song) -> String {
        "\(song.name) \(song.artists.first?.name ?? "")"
            .trimmingCharacters(in: .whitespaces)
    }

    static func matches(
        song: Song,
        title: String,
        artist: String,
        durationMS: Int
    ) -> Bool {
        guard song.durationMS > 0,
              durationMS > 0,
              abs(durationMS - song.durationMS) <= 5_000,
              normalized(title) == normalized(song.name),
              !hasVersionConflict(original: song.name, candidate: title)
        else { return false }

        let expectedArtist = normalized(song.artists.first?.name ?? "")
        guard !expectedArtist.isEmpty else { return false }
        return artistNames(in: artist).contains(expectedArtist)
    }

    private static let versionMarkers = [
        "live", "remix", "伴奏", "dj", "cover", "翻唱", "instrumental", "karaoke",
    ]

    private static func hasVersionConflict(
        original: String,
        candidate: String
    ) -> Bool {
        let originalMarkers = Set(
            versionMarkers.filter { normalized(original).contains($0) }
        )
        let candidateMarkers = Set(
            versionMarkers.filter { normalized(candidate).contains($0) }
        )
        return originalMarkers != candidateMarkers
    }

    private static func artistNames(in value: String) -> [String] {
        value.split(whereSeparator: { "/&、,，;；".contains($0) })
            .map { normalized(String($0)) }
            .filter { !$0.isEmpty }
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            .unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map { String($0) }
            .joined()
    }
}

enum GrayTrackUnblockService {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MeloX",
        category: "GrayTrackUnblock"
    )

    /// 按 pyncmd → 酷狗 → 酷我顺序解析，任一源成功即返回；全部失败返回 nil，
    /// 调用方保持原有失败行为不变。只解析已启用音源。
    static func resolve(
        song: Song,
        enabledSources: Set<GrayTrackSource>
    ) async -> GrayTrackResolution? {
        if enabledSources.contains(.pyncmd) {
            do {
                let url = try await resolvePyncmd(song: song)
                return GrayTrackResolution(source: .pyncmd, url: url)
            } catch {
                log.debug(
                    "pyncmd resolve failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        if enabledSources.contains(.kugou) {
            do {
                if let url = try await KugouProvider().resolve(song: song) {
                    return GrayTrackResolution(source: .kugou, url: url)
                }
            } catch {
                log.debug(
                    "kugou resolve failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        if enabledSources.contains(.kuwo) {
            do {
                if let url = try await KuwoProvider().resolve(song: song) {
                    return GrayTrackResolution(source: .kuwo, url: url)
                }
            } catch {
                log.debug(
                    "kuwo resolve failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        return nil
    }

    /// pyncmd：按网易云原曲 ID 直取播放地址，不需要歌名匹配。
    private static func resolvePyncmd(song: Song) async throws -> URL {
        let urlString =
            "https://music-api.gdstudio.xyz/api.php?types=url&source=netease&id=\(song.id)&br=320"
        let data = try await GrayTrackHTTPClient.shared.data(from: urlString)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw GrayTrackUnblockError.invalidResponse }
        guard let bitrate = object["br"] as? Int, bitrate > 0 else {
            throw GrayTrackUnblockError.missingBitrate
        }
        guard let urlValue = object["url"] as? String,
              let url = URL(
                string: urlValue.replacingOccurrences(of: "http://", with: "https://")
              )
        else { throw GrayTrackUnblockError.missingStreamURL }
        return url
    }

    private struct KugouProvider {
        func resolve(song: Song) async throws -> URL? {
            let keyword =
                GrayTrackMatcher.keyword(for: song)
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let searchURL =
                "https://mobilecdn.kugou.com/api/v3/search/song?format=json&keyword=\(keyword)&page=1&pagesize=10"
            let data = try await GrayTrackHTTPClient.shared.data(from: searchURL)
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObject = object["data"] as? [String: Any],
                  let info = dataObject["info"] as? [[String: Any]]
            else { throw GrayTrackUnblockError.invalidResponse }

            for item in info.prefix(5) {
                guard let hash = item["hash"] as? String,
                      let title = item["songname"] as? String,
                      let artist = item["singername"] as? String,
                      let duration = item["duration"] as? Int,
                      GrayTrackMatcher.matches(
                        song: song,
                        title: title,
                        artist: artist,
                        durationMS: duration * 1_000
                      )
                else { continue }

                let albumID: String
                if let albumString = item["album_id"] as? String {
                    albumID = albumString
                } else if let albumInt = item["album_id"] as? Int {
                    albumID = String(albumInt)
                } else {
                    albumID = "0"
                }
                let key = Insecure.MD5.hash(data: Data("\(hash)kgcloudv2".utf8))
                    .map { String(format: "%02x", $0) }
                    .joined()
                let streamURL =
                    "https://trackercdn.kugou.com/i/v2/?key=\(key)&hash=\(hash)&appid=1005&pid=2&cmd=25&behavior=play&album_id=\(albumID)"
                let streamData = try await GrayTrackHTTPClient.shared.data(from: streamURL)
                guard let streamObject = try JSONSerialization.jsonObject(with: streamData) as? [String: Any],
                      let urlString = (streamObject["url"] as? [String])?.first,
                      let url = URL(string: urlString)
                else { throw GrayTrackUnblockError.invalidResponse }
                return url
            }
            return nil
        }
    }

    private struct KuwoProvider {
        func resolve(song: Song) async throws -> URL? {
            let keyword =
                GrayTrackMatcher.keyword(for: song)
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let searchURL =
                "https://search.kuwo.cn/r.s?&correct=1&vipver=1&stype=comprehensive&encoding=utf8&rformat=json&mobi=1&show_copyright_off=1&searchapi=6&all=\(keyword)"
            let data = try await GrayTrackHTTPClient.shared.data(from: searchURL)
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = object["content"] as? [[String: Any]],
                  content.count >= 2,
                  let musicPage = content[1]["musicpage"] as? [String: Any],
                  let songs = musicPage["abslist"] as? [[String: Any]]
            else { throw GrayTrackUnblockError.invalidResponse }

            for item in songs.prefix(5) {
                guard let musicRID = item["MUSICRID"] as? String,
                      let rid = musicRID.components(separatedBy: "_").last,
                      let title = item["SONGNAME"] as? String,
                      let artist = item["ARTIST"] as? String
                else { continue }

                let durationSeconds: Int
                if let durationString = item["DURATION"] as? String,
                   let parsed = Int(durationString)
                {
                    durationSeconds = parsed
                } else if let durationInt = item["DURATION"] as? Int {
                    durationSeconds = durationInt
                } else {
                    durationSeconds = 0
                }
                guard GrayTrackMatcher.matches(
                    song: song,
                    title: title,
                    artist: artist,
                    durationMS: durationSeconds * 1_000
                ) else { continue }

                let convertURL =
                    "https://antiserver.kuwo.cn/anti.s?type=convert_url&format=mp3&response=url&rid=MUSIC_\(rid)"
                let body = try await GrayTrackHTTPClient.shared.data(
                    from: convertURL,
                    userAgent: "okhttp/3.10.0"
                )
                guard let text = String(data: body, encoding: .utf8),
                      let range = text.range(
                        of: #"http[^\s$"]+"#,
                        options: .regularExpression
                      ),
                      let url = URL(string: String(text[range]))
                else { throw GrayTrackUnblockError.invalidURL }
                return url
            }
            return nil
        }
    }
}
