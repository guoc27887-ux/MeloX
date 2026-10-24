import Foundation
import Observation

enum LyricsNotificationSupplementaryContent:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case none
    case translation
    case nextLyric
    case translationAndNextLyric

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            L10n.string("ui.settings.lyrics_notification.content.current")
        case .translation:
            L10n.string("ui.settings.lyrics_notification.content.translation")
        case .nextLyric:
            L10n.string("ui.settings.lyrics_notification.content.next")
        case .translationAndNextLyric:
            L10n.string("ui.settings.lyrics_notification.content.translation_and_next")
        }
    }

    var includesTranslation: Bool {
        self == .translation || self == .translationAndNextLyric
    }

    var includesNextLyric: Bool {
        self == .nextLyric || self == .translationAndNextLyric
    }
}

@MainActor
@Observable
final class LyricsNotificationPreferences {
    static let defaultIsEnabled = false
    static var defaultTitleFormat: String {
        L10n.string("ui.lyrics.format.token.title")
    }
    static let defaultShowsSubtitle = true
    static var defaultSubtitleFormat: String {
        L10n.string("ui.lyrics.format.token.artist")
    }
    static let defaultShowsArtwork = true
    static let defaultSupplementaryContent:
        LyricsNotificationSupplementaryContent = .translation
    static let defaultShowsTrackInfoWhenLyricsUnavailable = false
    static let defaultShowsInForeground = true
    static let defaultShowsInBackground = true
    static let defaultRemovesWhenPaused = true

    private enum Key {
        static let isEnabled = "lyricsNotifications.isEnabled"
        static let titleFormat = "lyricsNotifications.titleFormat"
        static let showsSubtitle =
            "lyricsNotifications.showsSubtitle"
        static let subtitleFormat =
            "lyricsNotifications.subtitleFormat"
        static let showsArtwork =
            "lyricsNotifications.showsArtwork"
        static let supplementaryContent =
            "lyricsNotifications.supplementaryContent"
        static let showsTrackInfoWhenLyricsUnavailable =
            "lyricsNotifications.showsTrackInfoWhenLyricsUnavailable"
        static let showsInForeground =
            "lyricsNotifications.showsInForeground"
        static let showsInBackground =
            "lyricsNotifications.showsInBackground"
        static let removesWhenPaused =
            "lyricsNotifications.removesWhenPaused"
    }

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Key.isEnabled)
        }
    }

    var titleFormat: String {
        didSet {
            defaults.set(titleFormat, forKey: Key.titleFormat)
        }
    }

    var showsSubtitle: Bool {
        didSet {
            defaults.set(
                showsSubtitle,
                forKey: Key.showsSubtitle
            )
        }
    }

    var subtitleFormat: String {
        didSet {
            defaults.set(subtitleFormat, forKey: Key.subtitleFormat)
        }
    }

    var showsArtwork: Bool {
        didSet {
            defaults.set(
                showsArtwork,
                forKey: Key.showsArtwork
            )
        }
    }

    var supplementaryContent:
        LyricsNotificationSupplementaryContent
    {
        didSet {
            defaults.set(
                supplementaryContent.rawValue,
                forKey: Key.supplementaryContent
            )
        }
    }

    var showsTrackInfoWhenLyricsUnavailable: Bool {
        didSet {
            defaults.set(
                showsTrackInfoWhenLyricsUnavailable,
                forKey: Key.showsTrackInfoWhenLyricsUnavailable
            )
        }
    }

    var showsInForeground: Bool {
        didSet {
            defaults.set(
                showsInForeground,
                forKey: Key.showsInForeground
            )
        }
    }

    var showsInBackground: Bool {
        didSet {
            defaults.set(
                showsInBackground,
                forKey: Key.showsInBackground
            )
        }
    }

    var removesWhenPaused: Bool {
        didSet {
            defaults.set(
                removesWhenPaused,
                forKey: Key.removesWhenPaused
            )
        }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(
            forKey: Key.isEnabled
        ) as? Bool ?? Self.defaultIsEnabled
        titleFormat = defaults.string(
            forKey: Key.titleFormat
        ) ?? Self.defaultTitleFormat
        showsSubtitle = defaults.object(
            forKey: Key.showsSubtitle
        ) as? Bool ?? Self.defaultShowsSubtitle
        subtitleFormat = defaults.string(
            forKey: Key.subtitleFormat
        ) ?? Self.defaultSubtitleFormat
        showsArtwork = defaults.object(
            forKey: Key.showsArtwork
        ) as? Bool ?? Self.defaultShowsArtwork
        supplementaryContent =
            LyricsNotificationSupplementaryContent(
                rawValue: defaults.string(
                    forKey: Key.supplementaryContent
                ) ?? ""
            ) ?? Self.defaultSupplementaryContent
        showsTrackInfoWhenLyricsUnavailable = defaults.object(
            forKey: Key.showsTrackInfoWhenLyricsUnavailable
        ) as? Bool
            ?? Self.defaultShowsTrackInfoWhenLyricsUnavailable
        showsInForeground = defaults.object(
            forKey: Key.showsInForeground
        ) as? Bool ?? Self.defaultShowsInForeground
        showsInBackground = defaults.object(
            forKey: Key.showsInBackground
        ) as? Bool ?? Self.defaultShowsInBackground
        removesWhenPaused = defaults.object(
            forKey: Key.removesWhenPaused
        ) as? Bool ?? Self.defaultRemovesWhenPaused
    }

    func reset() {
        isEnabled = Self.defaultIsEnabled
        titleFormat = Self.defaultTitleFormat
        showsSubtitle = Self.defaultShowsSubtitle
        subtitleFormat = Self.defaultSubtitleFormat
        showsArtwork = Self.defaultShowsArtwork
        supplementaryContent =
            Self.defaultSupplementaryContent
        showsTrackInfoWhenLyricsUnavailable =
            Self.defaultShowsTrackInfoWhenLyricsUnavailable
        showsInForeground =
            Self.defaultShowsInForeground
        showsInBackground =
            Self.defaultShowsInBackground
        removesWhenPaused =
            Self.defaultRemovesWhenPaused
    }
}
