import SwiftUI

struct BeatNetDebugSheet: View {
    @Environment(\.accessibilityDimFlashingLights)
    private var accessibilityDimFlashingLights
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLuminanceReduced)
    private var isLuminanceReduced
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player

    @State private var retryGeneration = 0

    var body: some View {
        NavigationStack {
            Form {
                analysisSection
                modelSection

                Section {
                    TimelineView(
                        .periodic(
                            from: .now,
                            by: 0.08
                        )
                    ) { context in
                        BeatNetRealtimeDebugPanel(
                            snapshot:
                                player.beatDebugSnapshot(
                                    at: context.date
                                ),
                            outputGate: outputGate
                        )
                    }
                } header: {
                    Text("ui.beatnet.debug.section.realtime")
                } footer: {
                    Text(
                        "ui.beatnet.debug.realtime.footer"
                    )
                }
            }
            .navigationTitle("ui.beatnet.debug.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("ui.common.done") {
                        dismiss()
                    }
                }
            }
        }
        .task(id: retryGeneration) {
            guard retryGeneration > 0 else {
                return
            }
            await player.analyzeCurrentSongBeats()
        }
    }

    private var analysisSection: some View {
        Section {
            LabeledContent(
                L10n.string("ui.common.song"),
                value:
                    player.currentSong?.name
                    ?? L10n.string("ui.player.no_current_song")
            )

            LabeledContent("ui.common.status") {
                analysisStatus
            }

            if case .ready(
                let bpm,
                let confidence
            ) = player.beatAnalysisStatus {
                LabeledContent(
                    L10n.string("ui.common.result"),
                    value:
                        "\(L10n.integer(Int(bpm.rounded()))) BPM · \(L10n.percent(confidence))"
                )
            }

            if case .failed(let message) =
                player.beatAnalysisStatus {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if showsAnalysisRetry {
                Button {
                    retryGeneration += 1
                } label: {
                    Label(
                        "ui.beatnet.debug.reanalyze",
                        systemImage: "arrow.clockwise"
                    )
                }
                .disabled(player.currentSong == nil)
            }
        } header: {
            Text("ui.beatnet.debug.section.analysis")
        } footer: {
            Text(
                "ui.beatnet.debug.analysis.footer"
            )
        }
    }

    private var modelSection: some View {
        Section {
            LabeledContent(
                L10n.string("ui.beatnet.debug.model"),
                value: L10n.string("ui.beatnet.debug.model_value")
            )
            LabeledContent("ui.beatnet.debug.input") {
                Text("1 × 1600 × 272 · Float32")
                    .monospacedDigit()
            }
            LabeledContent("ui.beatnet.debug.output") {
                Text("1 × 1600 × 2 · Float16")
                    .monospacedDigit()
            }
            LabeledContent(
                L10n.string("ui.beatnet.debug.output_channels"),
                value: L10n.string("ui.beatnet.debug.output_channels_value")
            )
            LabeledContent(
                L10n.string("ui.beatnet.debug.compute_units"),
                value: L10n.string("ui.beatnet.debug.cpu_only")
            )
            LabeledContent(
                L10n.string("ui.beatnet.debug.audio"),
                value: L10n.string("ui.beatnet.debug.audio_value")
            )
            LabeledContent(
                L10n.string("ui.beatnet.debug.inference"),
                value: L10n.string("ui.beatnet.debug.inference_value")
            )
            LabeledContent(
                L10n.string("ui.beatnet.debug.coverage"),
                value: L10n.string("ui.beatnet.debug.coverage_value")
            )
        } header: {
            Text("ui.beatnet.debug.section.core_ml")
        } footer: {
            Text(
                "ui.beatnet.debug.core_ml.footer"
            )
        }
    }

    @ViewBuilder
    private var analysisStatus: some View {
        switch player.beatAnalysisStatus {
        case .idle:
            Text("ui.beatnet.debug.status.waiting")
                .foregroundStyle(.secondary)
        case .analyzing:
            HStack(spacing: 7) {
                ProgressView()
                    .controlSize(.small)
                Text("ui.beatnet.debug.status.analyzing")
            }
            .foregroundStyle(.secondary)
        case .ready:
            Label(
                "ui.beatnet.debug.status.ready",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        case .failed:
            Label(
                "ui.beatnet.debug.status.failed",
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
        }
    }

    private var outputGate:
        BeatNetDebugOutputGate {
        guard settings.playerBackgroundStyle
            == .flowingLight else {
            return .blocked(L10n.string("ui.beatnet.debug.blocked.background_style"))
        }
        guard settings
            .playerBackgroundBeatEffectsEnabled else {
            return .blocked(L10n.string("ui.beatnet.debug.blocked.beat_effect_off"))
        }
        guard player.currentBeatTimeline != nil else {
            return .blocked(L10n.string("ui.beatnet.debug.blocked.no_timeline"))
        }
        guard player.isPlaying else {
            return .blocked(L10n.string("ui.beatnet.debug.blocked.paused"))
        }
        guard !accessibilityReduceMotion else {
            return .blocked(L10n.string("ui.beatnet.debug.blocked.reduce_motion"))
        }
        guard !accessibilityDimFlashingLights else {
            return .blocked(L10n.string("ui.beatnet.debug.blocked.dim_flashing_lights"))
        }
        guard !isLuminanceReduced else {
            return .blocked(L10n.string("ui.beatnet.debug.blocked.luminance"))
        }
        guard scenePhase == .active else {
            return .blocked(L10n.string("ui.beatnet.debug.blocked.background"))
        }
        return .active
    }

    private var showsAnalysisRetry: Bool {
        switch player.beatAnalysisStatus {
        case .idle, .failed:
            true
        case .analyzing, .ready:
            false
        }
    }

}

private struct BeatNetRealtimeDebugPanel: View {
    let snapshot: PlaybackBeatDebugSnapshot?
    let outputGate: BeatNetDebugOutputGate

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 13
        ) {
            LabeledContent("ui.beatnet.debug.player_output") {
                Label(
                    outputGate.title,
                    systemImage: outputGate.systemImage
                )
                .foregroundStyle(
                    outputGate.color
                )
            }

            if case .blocked(let reason) =
                outputGate {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if let snapshot {
                timelineRows(for: snapshot)

                Divider()

                LabeledContent(
                    L10n.string("ui.beatnet.debug.input_features"),
                    value: L10n.format(
                        "ui.beatnet.debug.input_features_value",
                        featureText(snapshot.featureStatistics.maximum),
                        featureText(snapshot.featureStatistics.mean)
                    )
                )
                LabeledContent(
                    L10n.string("ui.beatnet.debug.input_finite_values"),
                    value:
                        "\(snapshot.featureStatistics.finiteValueCount.formatted(.number.locale(L10n.locale))) / \(snapshot.featureStatistics.valueCount.formatted(.number.locale(L10n.locale)))"
                )
                LabeledContent(
                    L10n.string("ui.beatnet.debug.input_nonzero_values"),
                    value:
                        "\(snapshot.featureStatistics.nonzeroValueCount.formatted(.number.locale(L10n.locale))) / \(snapshot.featureStatistics.valueCount.formatted(.number.locale(L10n.locale)))"
                )
                LabeledContent(
                    L10n.string("ui.beatnet.debug.inference_path"),
                    value: L10n.string("ui.beatnet.debug.cpu_only")
                )
                LabeledContent(
                    L10n.string("ui.beatnet.debug.cpu_zero_segments"),
                    value:
                        "\(snapshot.finalAllZeroSegmentCount.formatted(.number.locale(L10n.locale)))/\(snapshot.analyzedSegmentCount.formatted(.number.locale(L10n.locale)))"
                )

                Divider()

                LabeledContent(
                    L10n.string("ui.beatnet.debug.full_track_raw_peak"),
                    value: L10n.format(
                        "ui.beatnet.debug.full_track_raw_peak_value",
                        activationText(
                            snapshot.maximumBeatActivation,
                            fractionLength: 5
                        ),
                        activationText(
                            snapshot.maximumDownbeatActivation,
                            fractionLength: 5
                        )
                    )
                )
                LabeledContent(
                    L10n.string("ui.beatnet.debug.raw_nonzero_frames"),
                    value: L10n.format(
                        "ui.beatnet.debug.raw_nonzero_frames_value",
                        snapshot.nonzeroBeatFrameCount,
                        snapshot.nonzeroDownbeatFrameCount
                    )
                )

                activationMeter(
                    L10n.format("ui.beatnet.debug.beat_raw_peak", modelPeakHoldMilliseconds),
                    value:
                        snapshot
                            .recentBeatActivation,
                    tint: .blue,
                    fractionLength: 5
                )
                activationMeter(
                    L10n.format("ui.beatnet.debug.downbeat_raw_peak", modelPeakHoldMilliseconds),
                    value:
                        snapshot
                            .recentDownbeatActivation,
                    tint: .orange,
                    fractionLength: 5
                )
                activationMeter(
                    L10n.string("ui.beatnet.debug.beat_current_joint_gate"),
                    value:
                        snapshot
                            .currentBeatActivation,
                    tint: .blue,
                    fractionLength: 5
                )
                activationMeter(
                    L10n.string("ui.beatnet.debug.downbeat_current_joint_gate"),
                    value:
                        snapshot
                            .currentDownbeatActivation,
                    tint: .orange,
                    fractionLength: 5
                )
                activationMeter(
                    L10n.string("ui.beatnet.debug.onset_joint_gate"),
                    value:
                        snapshot
                            .normalizedOnsetActivation,
                    tint: .pink
                )
                LabeledContent(
                    L10n.string("ui.beatnet.debug.vignette_condition"),
                    value:
                        L10n.format(
                            "ui.beatnet.debug.vignette_condition_value",
                            thresholdText(PlaybackBeatTimeline.modelVignetteTriggerThreshold),
                            thresholdText(PlaybackBeatTimeline.onsetVignetteTriggerThreshold)
                        )
                )
                LabeledContent(
                    L10n.string("ui.beatnet.debug.matching_debounce"),
                    value:
                        L10n.format(
                            "ui.beatnet.debug.matching_debounce_value",
                            modelToleranceMilliseconds,
                            minimumRetriggerMilliseconds
                        )
                )
                LabeledContent(
                    L10n.string("ui.beatnet.debug.downbeat_accent_threshold"),
                    value:
                        thresholdText(
                            PlaybackBeatTimeline
                                .downbeatVignetteAccentThreshold
                        )
                )
                LabeledContent("ui.beatnet.debug.recent_joint_gate") {
                    Label(
                        snapshot
                            .jointVignetteGateIsActive
                            ? L10n.string("ui.beatnet.debug.satisfied")
                            : L10n.string("ui.beatnet.debug.not_satisfied"),
                        systemImage:
                            snapshot
                                .jointVignetteGateIsActive
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                    .foregroundStyle(
                        snapshot
                            .jointVignetteGateIsActive
                            ? .green
                            : .secondary
                    )
                }

                Divider()

                activationMeter(
                    L10n.format("ui.beatnet.debug.recent_trigger_strength", modelPeakHoldMilliseconds),
                    value:
                        snapshot
                            .recentVignetteTriggerActivation,
                    tint: .pink
                )
                activationMeter(
                    L10n.string("ui.beatnet.debug.applied_vignette_envelope"),
                    value:
                        snapshot
                            .appliedVignettePulse,
                    tint: .pink
                )
                activationMeter(
                    L10n.string("ui.beatnet.debug.final_vignette_input"),
                    value: snapshot.vignettePulse,
                    tint: .purple
                )
            } else {
                ContentUnavailableView(
                    "ui.beatnet.debug.no_realtime_data",
                    systemImage: "waveform.slash",
                    description:
                        Text("ui.beatnet.debug.no_realtime_data.message")
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func timelineRows(
        for snapshot: PlaybackBeatDebugSnapshot
    ) -> some View {
        LabeledContent(
            L10n.string("ui.beatnet.debug.playback_position"),
            value: timeText(snapshot.playbackTime)
        )
        LabeledContent(
            L10n.string("ui.beatnet.debug.analysis_range"),
            value:
                "\(timeText(snapshot.regionStart))–\(timeText(snapshot.regionEnd))"
        )
        LabeledContent("ui.beatnet.debug.current_frame") {
            if let frameIndex =
                snapshot.frameIndex {
                Text(
                    "\(L10n.integer(frameIndex + 1)) / \(L10n.integer(snapshot.frameCount))"
                )
                .monospacedDigit()
            } else {
                Text("ui.beatnet.debug.out_of_range")
                    .foregroundStyle(.orange)
            }
        }
        LabeledContent(
            L10n.string("ui.beatnet.debug.decoded_events"),
            value: L10n.format(
                "ui.beatnet.debug.decoded_events_value",
                snapshot.decodedBeatCount,
                snapshot.decodedDownbeatCount
            )
        )
        LabeledContent("ui.beatnet.debug.beat_position") {
            if let beatOrdinal =
                snapshot.beatOrdinal,
               let beatInBar =
                snapshot.beatInBar {
                Text(
                    L10n.format("ui.beatnet.debug.beat_position_value", beatOrdinal, beatInBar)
                )
                .monospacedDigit()
            } else {
                Text("ui.beatnet.debug.before_first_beat")
                    .foregroundStyle(.secondary)
            }
        }
        LabeledContent("ui.beatnet.debug.since_previous_beat") {
            if let seconds =
                snapshot.secondsSinceBeat {
                Text(
                    L10n.format("ui.common.seconds_three_decimals", seconds)
                )
                .monospacedDigit()
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func activationMeter(
        _ title: String,
        value: Double,
        tint: Color,
        fractionLength: Int = 3
    ) -> some View {
        let clampedValue = min(
            max(value, 0),
            1
        )

        return VStack(
            alignment: .leading,
            spacing: 5
        ) {
            LabeledContent(title) {
                Text(
                    clampedValue.formatted(
                        .number.precision(
                            .fractionLength(fractionLength)
                        )
                        .locale(L10n.locale)
                    )
                )
                .monospacedDigit()
            }

            ProgressView(
                value: clampedValue,
                total: 1
            )
            .tint(tint)
        }
    }

    private func activationText(
        _ value: Double,
        fractionLength: Int = 3
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(
                    fractionLength
                )
            )
            .locale(L10n.locale)
        )
    }

    private func featureText(
        _ value: Float
    ) -> String {
        Double(value).formatted(
            .number.precision(
                .fractionLength(5)
            )
            .locale(L10n.locale)
        )
    }

    private func thresholdText(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(3)
            )
            .locale(L10n.locale)
        )
    }

    private var modelPeakHoldMilliseconds:
        Int {
        Int(
            (
                PlaybackBeatTimeline
                    .debugModelPeakHoldDuration
                    * 1_000
            ).rounded()
        )
    }

    private var modelToleranceMilliseconds:
        Int {
        Int(
            (
                PlaybackBeatTimeline
                    .vignetteModelTolerance
                    * 1_000
            ).rounded()
        )
    }

    private var minimumRetriggerMilliseconds:
        Int {
        Int(
            (
                PlaybackBeatTimeline
                    .vignetteMinimumRetriggerInterval
                    * 1_000
            ).rounded()
        )
    }

    private func timeText(
        _ time: TimeInterval
    ) -> String {
        let safeTime = max(time, 0)
        let minutes = Int(safeTime) / 60
        let seconds =
            safeTime
                - Double(minutes * 60)
        return String(
            format: "%d:%05.2f",
            minutes,
            seconds
        )
    }
}

private enum BeatNetDebugOutputGate:
    Equatable
{
    case active
    case blocked(String)

    var title: String {
        switch self {
        case .active:
            L10n.string("ui.beatnet.debug.output_active")
        case .blocked:
            L10n.string("ui.beatnet.debug.output_blocked")
        }
    }

    var systemImage: String {
        switch self {
        case .active:
            "checkmark.circle.fill"
        case .blocked:
            "pause.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .active:
            .green
        case .blocked:
            .orange
        }
    }
}
