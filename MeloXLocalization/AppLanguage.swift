import Foundation

nonisolated enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case simplifiedChinese

    static let storageKey = "melox.localization.language"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        case .english:
            Locale(identifier: "en")
        case .simplifiedChinese:
            Locale(identifier: "zh-Hans")
        }
    }

    var title: String {
        switch self {
        case .system:
            L10n.string("ui.settings.language.option.system")
        case .english:
            L10n.string("ui.settings.language.option.english")
        case .simplifiedChinese:
            L10n.string("ui.settings.language.option.simplified_chinese")
        }
    }

    static var selected: AppLanguage {
        guard let rawValue = UserDefaults.standard.string(forKey: storageKey)
        else {
            return .system
        }
        return AppLanguage(rawValue: rawValue) ?? .system
    }
}
