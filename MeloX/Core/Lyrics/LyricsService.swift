import Foundation

@MainActor
final class LyricsService {
    private enum FetchEvent: Sendable {
        case amll(String)
        case netease(NeteaseLyricPayload)
        case qqMusic(QQLyricPayload)
    }

    private struct CacheKey: Hashable {
        let song: LyricsSongMetadata
        let preference: LyricSourcePreference
        let usesAMLL: Bool
        let usesQQMusic: Bool
    }

    private let api: NeteaseAPI
    private let settings: AppSettings
    private let amllClient: AMLLLyricsClient
    private let qqMusicClient: QQMusicLyricsClient
    private var cache: [CacheKey: ResolvedLyrics] = [:]
    private var cacheOrder: [CacheKey] = []

    init(
        api: NeteaseAPI,
        settings: AppSettings,
        amllClient: AMLLLyricsClient = AMLLLyricsClient(),
        qqMusicClient: QQMusicLyricsClient = QQMusicLyricsClient()
    ) {
        self.api = api
        self.settings = settings
        self.amllClient = amllClient
        self.qqMusicClient = qqMusicClient
    }

    func load(
        for song: LyricsSongMetadata,
        onUpdate: @MainActor (ResolvedLyrics) -> Void
    ) async throws -> ResolvedLyrics {
        let preference = settings.lyricsSourcePreference
        let usesAMLL = preference.usesSource(
            .amll,
            enabledInAuto: settings.lyricsAMLLSourceEnabled
        )
        let usesQQMusic = preference.usesSource(
            .qqMusic,
            enabledInAuto: settings.lyricsQQMusicSourceEnabled
        )
        let cacheKey = CacheKey(
            song: song,
            preference: preference,
            usesAMLL: usesAMLL,
            usesQQMusic: usesQQMusic
        )
        var latest = cache[cacheKey]
        if let cached = latest {
            onUpdate(cached)
        }

        let api = api
        let amllClient = amllClient
        let qqMusicClient = qqMusicClient
        var sources = LyricSourceCollection()

        if preference == .automatic {
            // Load NetEase first so lyrics appear immediately instead of
            // waiting for the slower third-party lookups.
            if let payload = try? await api.neteaseLyrics(id: song.id) {
                sources.netease = payload
                publish(
                    LyricSourceMerger.resolve(sources, preference: .netease),
                    into: &latest,
                    onUpdate: onUpdate
                )
            }
            try Task.checkCancellation()

            // Wait for every remaining source before re-running the normal
            // automatic quality ranking with the complete collection.
            if usesAMLL || usesQQMusic {
                await withTaskGroup(of: FetchEvent?.self) { group in
                    if usesAMLL {
                        group.addTask {
                            guard let ttml = try? await amllClient.lyrics(songID: song.id) else {
                                return nil
                            }
                            return .amll(ttml)
                        }
                    }
                    if usesQQMusic {
                        group.addTask {
                            guard let payload = try? await qqMusicClient.lyrics(for: song) else {
                                return nil
                            }
                            return .qqMusic(payload)
                        }
                    }

                    for await event in group {
                        guard !Task.isCancelled, let event else { continue }
                        merge(event, into: &sources, song: song)
                    }
                }
                try Task.checkCancellation()
            }

            publish(
                LyricSourceMerger.resolve(sources, preference: .automatic),
                into: &latest,
                onUpdate: onUpdate
            )
        } else {
            await withTaskGroup(of: FetchEvent?.self) { group in
                group.addTask {
                    guard let payload = try? await api.neteaseLyrics(id: song.id) else {
                        return nil
                    }
                    return .netease(payload)
                }
                if usesAMLL {
                    group.addTask {
                        guard let ttml = try? await amllClient.lyrics(songID: song.id) else {
                            return nil
                        }
                        return .amll(ttml)
                    }
                }
                if usesQQMusic {
                    group.addTask {
                        guard let payload = try? await qqMusicClient.lyrics(for: song) else {
                            return nil
                        }
                        return .qqMusic(payload)
                    }
                }

                for await event in group {
                    guard !Task.isCancelled, let event else { continue }
                    guard merge(event, into: &sources, song: song) else {
                        continue
                    }
                    publish(
                        LyricSourceMerger.resolve(
                            sources,
                            preference: preference
                        ),
                        into: &latest,
                        onUpdate: onUpdate
                    )
                }
            }
        }

        try Task.checkCancellation()
        guard let latest else { throw LyricSourceError.noLyrics }
        store(latest, for: cacheKey)
        return latest
    }

    @discardableResult
    private func merge(
        _ event: FetchEvent,
        into sources: inout LyricSourceCollection,
        song: LyricsSongMetadata
    ) -> Bool {
        switch event {
        case .amll(let ttml):
            // AMLL is keyed by the NetEase song ID, but a few files in its
            // database carry different metadata. Never let a mismatched TTML
            // win automatic priority.
            if let metadata = AMLLLyricMetadata(ttml: ttml),
               !metadata.matches(song: song) {
                return false
            }
            sources.amllTTML = ttml
        case .netease(let payload):
            sources.netease = payload
        case .qqMusic(let payload):
            sources.qqMusic = payload
        }
        return true
    }

    private func publish(
        _ resolved: ResolvedLyrics?,
        into latest: inout ResolvedLyrics?,
        onUpdate: @MainActor (ResolvedLyrics) -> Void
    ) {
        guard let resolved else { return }
        guard latest.map({
            resolved != $0 && resolved.quality.rawValue >= $0.quality.rawValue
        }) ?? true else { return }
        latest = resolved
        onUpdate(resolved)
    }

    private func store(_ lyrics: ResolvedLyrics, for key: CacheKey) {
        cache[key] = lyrics
        cacheOrder.removeAll { $0 == key }
        cacheOrder.append(key)
        while cacheOrder.count > 48 {
            cache.removeValue(forKey: cacheOrder.removeFirst())
        }
    }
}

private extension LyricSourcePreference {
    func usesSource(
        _ source: LyricSource,
        enabledInAuto: Bool
    ) -> Bool {
        switch self {
        case .automatic:
            enabledInAuto
        case .amll:
            source == .amll
        case .netease:
            source == .netease
        case .qqMusic:
            source == .qqMusic
        }
    }
}
