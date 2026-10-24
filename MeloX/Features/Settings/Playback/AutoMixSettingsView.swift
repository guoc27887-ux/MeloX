import SwiftUI

struct AutoMixSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player

    var body: some View {
        @Bindable var preferences = settings.autoMix

        Form {
            Section {
                Toggle(
                    "ui.settings.automix.enabled",
                    isOn: Binding(
                        get: { player.isAutoMixEnabled },
                        set: { player.setAutoMixEnabled($0) }
                    )
                )

                Picker("ui.settings.automix.transition_mode", selection: $preferences.mode) {
                    ForEach(AutoMixMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            } header: {
                Text("ui.settings.automix.section.mode")
            } footer: {
                Text(preferences.mode.description)
            }

            if preferences.mode == .smart {
                Section {
                    Picker(
                        "ui.settings.automix.transition_length",
                        selection: $preferences.transitionBars
                    ) {
                        ForEach(AutoMixTransitionBars.allCases) { bars in
                            Text(bars.title).tag(bars)
                        }
                    }

                    Picker(
                        "ui.settings.automix.previous_end_position",
                        selection: $preferences.tailCutBars
                    ) {
                        ForEach(AutoMixTailCutBars.allCases) {
                            timing in
                            Text(timing.title).tag(timing)
                        }
                    }

                    Toggle(
                        "ui.settings.automix.match_tempo",
                        isOn: $preferences.tempoMatchingEnabled
                    )

                    if preferences.tempoMatchingEnabled {
                        valueSlider(
                            title: L10n.string("ui.settings.automix.maximum_tempo_adjustment"),
                            value:
                                $preferences
                                    .maximumTempoAdjustmentPercent,
                            range:
                                AutoMixPreferences
                                    .maximumTempoAdjustmentPercentRange,
                            step: 0.5,
                            valueText:
                                preferences.maximumTempoAdjustmentPercent.formatted(
                                    .number
                                        .precision(.fractionLength(1))
                                        .locale(L10n.locale)
                                ) + "%"
                        )
                    }

                    Toggle(
                        "ui.settings.automix.skip_quiet_opening",
                        isOn: $preferences.skipsQuietOpening
                    )

                    valueSlider(
                        title: L10n.string("ui.settings.automix.minimum_confidence"),
                        value: $preferences.minimumAnalysisConfidence,
                        range:
                            AutoMixPreferences
                                .minimumAnalysisConfidenceRange,
                        step: 0.05,
                        valueText:
                            L10n.percent(preferences.minimumAnalysisConfidence)
                    )

                    Toggle(
                        "ui.settings.automix.analyze_streaming",
                        isOn: $preferences.analyzesStreamingTracks
                    )
                } header: {
                    Text("ui.settings.automix.section.smart_analysis")
                } footer: {
                    Text(
                        "ui.settings.automix.smart_analysis.footer"
                    )
                }
            }

            Section {
                if preferences.mode == .fixed
                    || preferences.fallbackBehavior == .crossfade {
                    valueSlider(
                        title: L10n.string("ui.settings.automix.crossfade_duration"),
                        value: $preferences.fixedDuration,
                        range: AutoMixPreferences.fixedDurationRange,
                        step: 0.5,
                        valueText:
                            L10n.format("ui.common.seconds_decimal", preferences.fixedDuration)
                    )
                }

                valueSlider(
                    title: L10n.string("ui.settings.automix.preload_lead_time"),
                    value: $preferences.preloadLeadTime,
                    range: AutoMixPreferences.preloadLeadTimeRange,
                    step: 5,
                    valueText: L10n.format("ui.common.seconds", Int(preferences.preloadLeadTime))
                )

                Picker("ui.settings.automix.fade_curve", selection: $preferences.fadeCurve) {
                    ForEach(AutoMixFadeCurve.allCases) { curve in
                        Text(curve.title).tag(curve)
                    }
                }
            } header: {
                Text("ui.settings.playback.section.playback")
            } footer: {
                Text(
                    L10n.format(
                        "ui.settings.automix.playback.footer",
                        preferences.fadeCurve.description
                    )
                )
            }

            if preferences.mode == .smart {
                Section {
                    Picker(
                        "ui.settings.automix.analysis_unavailable",
                        selection: $preferences.fallbackBehavior
                    ) {
                        ForEach(AutoMixFallbackBehavior.allCases) {
                            behavior in
                            Text(behavior.title).tag(behavior)
                        }
                    }
                } header: {
                    Text("ui.settings.automix.section.failure_strategy")
                } footer: {
                    Text(preferences.fallbackBehavior.description)
                }
            }
        }
        .navigationTitle("ui.settings.automix.title")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: preferences.configuration) {
            player.applyAutoMixSettings()
        }
    }

    private func valueSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(title, value: valueText)
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
        }
    }
}
