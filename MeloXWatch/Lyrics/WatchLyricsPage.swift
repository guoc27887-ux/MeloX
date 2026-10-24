import SwiftUI

struct WatchLyricsPage: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator
    @EnvironmentObject private var lyricsStore: WatchLyricsStore

    @AppStorage(WatchPreferenceKey.showsTranslation)
    private var showsTranslation = true
    @AppStorage(WatchPreferenceKey.showsRomanization)
    private var showsRomanization = false
    @AppStorage(WatchPreferenceKey.wordByWord)
    private var usesWordByWordHighlight = true
    @AppStorage(WatchPreferenceKey.lyricGlow)
    private var usesGlow = true
    @AppStorage(WatchPreferenceKey.lyricGlowIntensity)
    private var glowIntensity = 1.0
    @AppStorage(WatchPreferenceKey.lyricAdvanceTime)
    private var advanceTime = 0.2
    @AppStorage(WatchPreferenceKey.lyricBlurIntensity)
    private var blurIntensity = 0.8
    @AppStorage(WatchPreferenceKey.lyricDistanceBlurScale)
    private var distanceBlurScale = 1.05
    @AppStorage(WatchPreferenceKey.lyricCurrentLineScale)
    private var currentLineScale = 1.02
    @AppStorage(WatchPreferenceKey.lyricHighRefreshRate)
    private var refreshRateRawValue = WatchLyricsRefreshRate.smooth.rawValue
    @AppStorage(WatchPreferenceKey.lyricDimAmount)
    private var dimAmount = 1.0
    @AppStorage(WatchPreferenceKey.lyricFocusPosition)
    private var focusPosition = 0.25
    @AppStorage(WatchPreferenceKey.lyricUniformBrowsingDimming)
    private var usesUniformBrowsingDimming = true
    @AppStorage(WatchPreferenceKey.lyricRomanizationFontScale)
    private var romanizationFontScale = 0.65
    @AppStorage(WatchPreferenceKey.lyricRomanizationOpacity)
    private var romanizationOpacity = 0.9
    @AppStorage(WatchPreferenceKey.lyricLiftMode)
    private var liftModeRawValue = WatchLyricTimingMode.character.rawValue
    @AppStorage(WatchPreferenceKey.lyricLongToneDetectionMode)
    private var longToneDetectionModeRawValue =
        WatchLyricTimingMode.character.rawValue
    @AppStorage(WatchPreferenceKey.lyricLongToneDurationThreshold)
    private var longToneDurationThreshold = 0.95
    @AppStorage(WatchPreferenceKey.lyricLongToneExpansionAmount)
    private var longToneExpansionAmount = 0.05

    let isActive: Bool

    var body: some View {
        Group {
            if !isActive {
                Color.black
            } else if lyricsStore.isLoading {
                ProgressView("ui.watch.lyrics.loading")
            } else if lyricsStore.lyrics.isEmpty {
                ContentUnavailableView(
                    "ui.watch.lyrics.empty.title",
                    systemImage: "quote.bubble",
                    description: Text(
                        lyricsStore.errorMessage
                            ?? L10n.string(
                                "ui.watch.lyrics.empty.description"
                            )
                    )
                )
            } else {
                activeLyrics
            }
        }
        .task(id: loadRequest) {
            guard loadRequest.isActive else { return }
            await lyricsStore.load(songID: loadRequest.songID)
        }
        .background(.black)
        .clipped()
        .ignoresSafeArea(.container, edges: .all)
    }

    private var activeLyrics: some View {
        TimelineView(
            .animation(
                minimumInterval: refreshRate.minimumInterval,
                paused: !coordinator.isPlaying
            )
        ) { context in
            WatchLyricsView(
                lyrics: lyricsStore.lyrics,
                progress:
                    coordinator.position(at: context.date)
                    + lyricsPreferences.advanceTime,
                preferences: lyricsPreferences
            ) { line in
                coordinator.seek(to: line.time)
            }
        }
    }

    private var loadRequest: WatchLyricsLoadRequest {
        WatchLyricsLoadRequest(
            songID: coordinator.song?.id,
            isActive: isActive
        )
    }

    private var lyricsPreferences: MeloXWatchLyricsPreferences {
        var preferences = MeloXWatchLyricsPreferences.standard
        preferences.showsTranslation = showsTranslation
        preferences.showsRomanization = showsRomanization
        preferences.usesWordByWordHighlight = usesWordByWordHighlight
        preferences.usesGlow = usesGlow
        preferences.glowIntensity = glowIntensity
        preferences.advanceTime = advanceTime
        preferences.blurIntensity = blurIntensity
        preferences.distanceBlurScale = distanceBlurScale
        preferences.currentLineScale = currentLineScale
        preferences.dimAmount = dimAmount
        preferences.focusPosition = focusPosition
        preferences.usesUniformDimmingWhileBrowsing =
            usesUniformBrowsingDimming
        preferences.romanizationFontScale = romanizationFontScale
        preferences.romanizationOpacity = romanizationOpacity
        preferences.liftModeRawValue = liftModeRawValue
        preferences.longToneDetectionModeRawValue =
            longToneDetectionModeRawValue
        preferences.longToneDurationThreshold =
            longToneDurationThreshold
        preferences.longToneExpansionAmount = longToneExpansionAmount
        return preferences
    }

    private var refreshRate: WatchLyricsRefreshRate {
        WatchLyricsRefreshRate(rawValue: refreshRateRawValue) ?? .smooth
    }
}

private struct WatchLyricsLoadRequest: Hashable {
    let songID: Int?
    let isActive: Bool
}
