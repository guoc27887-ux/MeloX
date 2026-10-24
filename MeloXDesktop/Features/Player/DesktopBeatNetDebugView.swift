import SwiftUI

struct DesktopBeatNetDebugView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var retryGeneration = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ui.beatnet.debug.title")
                    .font(.system(size: 24, weight: .bold))
                Spacer()
                Button("ui.common.done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(22)

            Divider()

            Form {
                analysisSection

                Section("ui.beatnet.debug.section.realtime") {
                    TimelineView(.periodic(from: .now, by: 0.08)) {
                        context in
                        realtimePanel(
                            snapshot: model.player.beatDebugSnapshot(
                                at: context.date
                            )
                        )
                    }
                }

                Section("ui.beatnet.debug.model") {
                    LabeledContent("ui.beatnet.debug.model", value: L10n.string("ui.beatnet.debug.model_value"))
                    LabeledContent("ui.beatnet.debug.input", value: "1 × 1600 × 272 · Float32")
                    LabeledContent("ui.beatnet.debug.output", value: L10n.string("ui.beatnet.debug.output_channels_value"))
                    LabeledContent("ui.beatnet.debug.audio", value: L10n.string("ui.beatnet.debug.audio_value"))
                    LabeledContent("ui.beatnet.debug.compute_units", value: L10n.string("ui.beatnet.debug.cpu_only"))
                }
            }
            .formStyle(.grouped)
            .padding(12)
        }
        .frame(width: 680, height: 640)
        .task(id: retryGeneration) {
            guard retryGeneration > 0 else { return }
            await model.player.analyzeCurrentSongBeats()
        }
    }

    private var analysisSection: some View {
        Section("ui.beatnet.debug.section.analysis") {
            LabeledContent(
                "ui.desktop.beatnet.song",
                value: model.player.currentSong?.name ?? L10n.string("ui.desktop.player.not_playing")
            )

            LabeledContent("ui.desktop.beatnet.status") {
                analysisStatus
            }

            if case .ready(let bpm, let confidence) =
                model.player.beatAnalysisStatus {
                LabeledContent(
                    "ui.desktop.beatnet.result",
                    value:
                        "\(L10n.integer(Int(bpm.rounded()))) BPM · \(percentage(confidence))"
                )
            }

            if case .failed(let message) = model.player.beatAnalysisStatus {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Button("ui.beatnet.debug.reanalyze", systemImage: "arrow.clockwise") {
                model.player.clearCurrentSongBeatAnalysis()
                retryGeneration += 1
            }
            .disabled(
                model.player.currentSong == nil
                    || model.player.beatAnalysisStatus == .analyzing
            )
        }
    }

    @ViewBuilder
    private var analysisStatus: some View {
        switch model.player.beatAnalysisStatus {
        case .idle:
            Text("ui.beatnet.debug.status.waiting")
                .foregroundStyle(.secondary)
        case .analyzing:
            HStack(spacing: 7) {
                ProgressView()
                    .controlSize(.small)
                Text("ui.beatnet.debug.status.analyzing")
            }
        case .ready:
            Label("ui.beatnet.debug.status.ready", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Label("ui.beatnet.debug.status.failed", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private func realtimePanel(
        snapshot: PlaybackBeatDebugSnapshot?
    ) -> some View {
        if let snapshot {
            LabeledContent(
                "ui.beatnet.debug.playback_position",
                value: seconds(snapshot.playbackTime)
            )
            LabeledContent(
                "ui.desktop.beatnet.bpm_confidence",
                value:
                    "\(L10n.integer(Int(snapshot.bpm.rounded()))) / \(percentage(snapshot.confidence))"
            )
            LabeledContent(
                "ui.desktop.beatnet.beat",
                value: snapshot.beatInBar.map {
                    L10n.format("ui.desktop.beatnet.beat_number", $0)
                } ?? "—"
            )
            LabeledContent(
                "ui.desktop.beatnet.beat_downbeat",
                value:
                    "\(activation(snapshot.recentBeatActivation)) / \(activation(snapshot.recentDownbeatActivation))"
            )
            LabeledContent(
                "ui.desktop.beatnet.onset",
                value: activation(snapshot.normalizedOnsetActivation)
            )
            LabeledContent(
                "ui.desktop.beatnet.vignette_trigger",
                value: snapshot.jointVignetteGateIsActive
                    ? L10n.string("ui.desktop.beatnet.triggered")
                    : L10n.string("ui.desktop.beatnet.not_triggered")
            )
            LabeledContent(
                "ui.desktop.beatnet.vignette_intensity",
                value: activation(snapshot.appliedVignettePulse)
            )
            LabeledContent(
                "ui.desktop.beatnet.analysis_frame",
                value: snapshot.frameIndex.map {
                    "\(L10n.integer($0 + 1)) / \(L10n.integer(snapshot.frameCount))"
                } ?? L10n.string("ui.beatnet.debug.out_of_range")
            )
        } else {
            Text("ui.beatnet.debug.blocked.no_timeline")
                .foregroundStyle(.secondary)
        }
    }

    private func percentage(_ value: Double) -> String {
        value.formatted(
            .percent.precision(.fractionLength(0)).locale(L10n.locale)
        )
    }

    private func activation(_ value: Double) -> String {
        value.formatted(
            .number.precision(.fractionLength(3)).locale(L10n.locale)
        )
    }

    private func seconds(_ value: TimeInterval) -> String {
        L10n.format("ui.common.seconds_two_decimals", value)
    }
}
