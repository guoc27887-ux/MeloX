import Foundation

struct LyricsLiveActivityPreferences: Equatable {
    let titleFormat: String
    let subtitleFormat: String
    let compactFormat: String
    let showsArtwork: Bool
    let showsNextLyric: Bool
    let showsProgress: Bool
    let scrollsCompactText: Bool
    let compactTextSize: LyricsLiveActivityCompactTextSize
    let scrollSpeed: Double
    let scrollPause: TimeInterval

    init(settings: AppSettings) {
        titleFormat = settings.lyricsLiveActivityTitleFormat
        subtitleFormat = settings.lyricsLiveActivitySubtitleFormat
        compactFormat = settings.lyricsLiveActivityCompactFormat
        showsArtwork = settings.lyricsLiveActivityShowsArtwork
        showsNextLyric = settings.lyricsLiveActivityShowsNextLyric
        showsProgress = settings.lyricsLiveActivityShowsProgress
        scrollsCompactText =
            settings.lyricsLiveActivityScrollsCompactText
        compactTextSize =
            settings.lyricsLiveActivityCompactTextSize
        scrollSpeed = settings.lyricsLiveActivityScrollSpeed
        scrollPause = settings.lyricsLiveActivityScrollPause
    }

    var presentation: LyricsLiveActivityPresentation {
        LyricsLiveActivityPresentation(
            showsArtwork: showsArtwork,
            showsNextLyric: showsNextLyric,
            showsProgress: showsProgress,
            scrollsCompactText: scrollsCompactText,
            compactTextSize: compactTextSize,
            scrollSpeed: scrollSpeed,
            scrollPause: scrollPause
        )
    }
}
