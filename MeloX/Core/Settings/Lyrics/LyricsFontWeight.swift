import SwiftUI
import UIKit

enum LyricsFontWeight: String, CaseIterable, Identifiable {
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: L10n.string("ui.settings.font_weight.light")
        case .regular: L10n.string("ui.settings.font_weight.regular")
        case .medium: L10n.string("ui.settings.font_weight.medium")
        case .semibold: L10n.string("ui.settings.font_weight.semibold")
        case .bold: L10n.string("ui.settings.font_weight.bold")
        case .heavy: L10n.string("ui.settings.font_weight.heavy")
        }
    }

    var swiftUIWeight: Font.Weight {
        switch self {
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
    }

    var uiKitWeight: UIFont.Weight {
        switch self {
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
    }
}
