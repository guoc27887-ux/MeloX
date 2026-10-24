// PV Tool — Copyright (c) 2026 DanteAlighieri13210914
// Template metadata ported under the PV Tool Non-Commercial License.

import Foundation
import Observation

// Template order and names mirror pv-tool/src/templates/index.ts.
enum TextPVStyle: String, CaseIterable, Identifiable {
    case blueBold
    case kineticSplit
    case bluePlane
    case cyberGrunge
    case geometric
    case rainCity
    case cyberpunkHUD
    case emotionCinema
    case hystericNight
    case spiderWeb
    case staggeredText
    case calmVillain
    case girlyClouds
    case sweetPink
    case flyMeToTheMoon
    case kawaiPixel
    case crimeScene
    case haruhikage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blueBold: L10n.string("ui.settings.text_pv.style.blue_bold")
        case .kineticSplit: L10n.string("ui.settings.text_pv.style.kinetic_split")
        case .bluePlane: L10n.string("ui.settings.text_pv.style.blue_plane")
        case .cyberGrunge: L10n.string("ui.settings.text_pv.style.cyber_grunge")
        case .geometric: L10n.string("ui.settings.text_pv.style.geometric")
        case .rainCity: L10n.string("ui.settings.text_pv.style.rain_city")
        case .cyberpunkHUD: L10n.string("ui.settings.text_pv.style.cyberpunk_hud")
        case .emotionCinema: L10n.string("ui.settings.text_pv.style.emotion_cinema")
        case .hystericNight: L10n.string("ui.settings.text_pv.style.hysteric_night")
        case .spiderWeb: L10n.string("ui.settings.text_pv.style.spider_web")
        case .staggeredText: L10n.string("ui.settings.text_pv.style.staggered_text")
        case .calmVillain: L10n.string("ui.settings.text_pv.style.calm_villain")
        case .girlyClouds: L10n.string("ui.settings.text_pv.style.girly_clouds")
        case .sweetPink: L10n.string("ui.settings.text_pv.style.sweet_pink")
        case .flyMeToTheMoon: L10n.string("ui.settings.text_pv.style.fly_me_to_the_moon")
        case .kawaiPixel: L10n.string("ui.settings.text_pv.style.kawaii_pixel")
        case .crimeScene: L10n.string("ui.settings.text_pv.style.crime_scene")
        case .haruhikage: L10n.string("ui.settings.text_pv.style.haruhikage")
        }
    }

    var description: String {
        switch self {
        case .blueBold: L10n.string("ui.settings.text_pv.style.blue_bold.detail")
        case .kineticSplit: L10n.string("ui.settings.text_pv.style.kinetic_split.detail")
        case .bluePlane: L10n.string("ui.settings.text_pv.style.blue_plane.detail")
        case .cyberGrunge: L10n.string("ui.settings.text_pv.style.cyber_grunge.detail")
        case .geometric: L10n.string("ui.settings.text_pv.style.geometric.detail")
        case .rainCity: L10n.string("ui.settings.text_pv.style.rain_city.detail")
        case .cyberpunkHUD: L10n.string("ui.settings.text_pv.style.cyberpunk_hud.detail")
        case .emotionCinema: L10n.string("ui.settings.text_pv.style.emotion_cinema.detail")
        case .hystericNight: L10n.string("ui.settings.text_pv.style.hysteric_night.detail")
        case .spiderWeb: L10n.string("ui.settings.text_pv.style.spider_web.detail")
        case .staggeredText: L10n.string("ui.settings.text_pv.style.staggered_text.detail")
        case .calmVillain: L10n.string("ui.settings.text_pv.style.calm_villain.detail")
        case .girlyClouds: L10n.string("ui.settings.text_pv.style.girly_clouds.detail")
        case .sweetPink: L10n.string("ui.settings.text_pv.style.sweet_pink.detail")
        case .flyMeToTheMoon: L10n.string("ui.settings.text_pv.style.fly_me_to_the_moon.detail")
        case .kawaiPixel: L10n.string("ui.settings.text_pv.style.kawaii_pixel.detail")
        case .crimeScene: L10n.string("ui.settings.text_pv.style.crime_scene.detail")
        case .haruhikage: L10n.string("ui.settings.text_pv.style.haruhikage.detail")
        }
    }

    var systemImage: String {
        switch self {
        case .blueBold: "bolt.fill"
        case .kineticSplit: "line.diagonal"
        case .bluePlane: "circle.grid.cross"
        case .cyberGrunge: "waveform.path.ecg"
        case .geometric: "square.on.square"
        case .rainCity: "text.line.first.and.arrowtriangle.forward"
        case .cyberpunkHUD: "viewfinder"
        case .emotionCinema: "film"
        case .hystericNight: "rays"
        case .spiderWeb: "point.3.filled.connected.trianglepath.dotted"
        case .staggeredText: "textformat.size.larger"
        case .calmVillain: "scope"
        case .girlyClouds: "cloud.fill"
        case .sweetPink: "circle.grid.2x2.fill"
        case .flyMeToTheMoon: "moon.stars.fill"
        case .kawaiPixel: "macwindow"
        case .crimeScene: "exclamationmark.triangle.fill"
        case .haruhikage: "scribble.variable"
        }
    }

    var referenceAnimationSpeed: Double {
        switch self {
        case .staggeredText: 3.4
        case .girlyClouds: 1.5
        case .sweetPink, .kawaiPixel: 1
        case .flyMeToTheMoon: 3.7
        case .crimeScene: 2.5
        case .haruhikage: 0.8
        default: 2
        }
    }

    var minimumRenderInterval: TimeInterval {
        switch self {
        case .rainCity, .hystericNight, .calmVillain, .crimeScene, .haruhikage:
            1.0 / 30.0
        default:
            1.0 / 60.0
        }
    }
}

@MainActor
@Observable
final class TextPVPreferences {
    static let defaultStyle = TextPVStyle.blueBold
    static let defaultMotionIntensity = 1.0
    static let motionIntensityRange = 0.0...2.0
    static let defaultAnimationSpeed = 2.0
    static let animationSpeedRange = 0.0...4.0

    private enum Key {
        static let style = "textPVStyle"
        static let motionIntensity = "textPVMotionIntensity"
        static let animationSpeed = "textPVAnimationSpeed"
    }

    var style: TextPVStyle {
        didSet {
            defaults.set(style.rawValue, forKey: Key.style)
            guard style != oldValue else { return }
            animationSpeed = style.referenceAnimationSpeed
        }
    }

    var motionIntensity: Double {
        didSet { defaults.set(motionIntensity, forKey: Key.motionIntensity) }
    }

    var animationSpeed: Double {
        didSet { defaults.set(animationSpeed, forKey: Key.animationSpeed) }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedStyle = TextPVStyle(
            rawValue: defaults.string(forKey: Key.style) ?? ""
        ) ?? Self.defaultStyle
        style = storedStyle
        motionIntensity = (defaults.object(forKey: Key.motionIntensity) as? Double
            ?? Self.defaultMotionIntensity)
            .clamped(to: Self.motionIntensityRange)
        animationSpeed = (defaults.object(forKey: Key.animationSpeed) as? Double
            ?? storedStyle.referenceAnimationSpeed)
            .clamped(to: Self.animationSpeedRange)
    }

    func reset() {
        style = Self.defaultStyle
        motionIntensity = Self.defaultMotionIntensity
        animationSpeed = Self.defaultAnimationSpeed
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
