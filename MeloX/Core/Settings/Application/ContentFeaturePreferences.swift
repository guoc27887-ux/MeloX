import Foundation
import Observation

enum ContentFeature: String, CaseIterable, Identifiable {
    case podcasts
    case downloads
    case cloudMusic
    case listeningHistory

    var id: Self { self }

    var title: String {
        switch self {
        case .podcasts: L10n.string("ui.settings.content_feature.podcasts.title")
        case .downloads: L10n.string("ui.navigation.downloads")
        case .cloudMusic: L10n.string("ui.settings.content_feature.cloud.title")
        case .listeningHistory: L10n.string("ui.navigation.recently_played")
        }
    }

    var detail: String {
        switch self {
        case .podcasts: L10n.string("ui.settings.content_feature.podcasts.detail")
        case .downloads: L10n.string("ui.settings.content_feature.downloads.detail")
        case .cloudMusic: L10n.string("ui.settings.content_feature.cloud.detail")
        case .listeningHistory: L10n.string("ui.settings.content_feature.history.detail")
        }
    }

    var systemImage: String {
        switch self {
        case .podcasts: "dot.radiowaves.left.and.right"
        case .downloads: "arrow.down.circle"
        case .cloudMusic: "icloud"
        case .listeningHistory: "clock"
        }
    }

    static var availableCases: [ContentFeature] {
        allCases.filter {
            $0 != .downloads || AppFeatureAvailability.downloads
        }
    }
}

@MainActor
@Observable
final class ContentFeaturePreferences {
    private enum Key {
        static let disabledFeatures =
            "melox.contentFeatures.disabledFeatures"
    }

    private(set) var disabledFeatures: Set<ContentFeature> {
        didSet {
            defaults.set(
                disabledFeatures.map(\.rawValue).sorted(),
                forKey: Key.disabledFeatures
            )
        }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        disabledFeatures = Set(
            (defaults.array(forKey: Key.disabledFeatures) as? [String])?
                .compactMap(ContentFeature.init(rawValue:)) ?? []
        )
    }

    func isEnabled(_ feature: ContentFeature) -> Bool {
        ContentFeature.availableCases.contains(feature)
            && !disabledFeatures.contains(feature)
    }

    func setEnabled(_ isEnabled: Bool, for feature: ContentFeature) {
        guard ContentFeature.availableCases.contains(feature) else { return }
        if isEnabled {
            disabledFeatures.remove(feature)
        } else {
            disabledFeatures.insert(feature)
        }
    }
}
