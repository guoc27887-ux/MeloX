import SwiftUI

struct PlaybackSleepTimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerStore.self) private var player

    var body: some View {
        NavigationStack {
            Form {
                if let endDate = player.sleepTimer.endDate {
                    activeTimerSection(endDate: endDate)
                }

                Section {
                    ForEach(PlaybackSleepTimerPreset.allCases) { preset in
                        Button {
                            player.sleepTimer.start(
                                duration: preset.duration
                            )
                            dismiss()
                        } label: {
                            Label(
                                preset.title,
                                systemImage: "clock"
                            )
                        }
                    }
                } header: {
                    Text(
                        player.sleepTimer.isActive
                            ? L10n.string("ui.sleep_timer.reset")
                            : L10n.string("ui.sleep_timer.stop_time")
                    )
                } footer: {
                    Text("ui.sleep_timer.message")
                }

                if player.sleepTimer.isActive {
                    Section {
                        Button("ui.sleep_timer.cancel", role: .destructive) {
                            player.sleepTimer.cancel()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("ui.sleep_timer.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("ui.common.done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func activeTimerSection(endDate: Date) -> some View {
        Section {
            LabeledContent("ui.sleep_timer.remaining") {
                Text(
                    timerInterval:
                        min(Date.now, endDate)...endDate,
                    countsDown: true
                )
                .monospacedDigit()
            }

            LabeledContent("ui.sleep_timer.estimated_stop") {
                Text(
                    endDate,
                    format: .dateTime.hour().minute()
                )
            }
        } header: {
            Text("ui.sleep_timer.current")
        }
    }
}

private enum PlaybackSleepTimerPreset: Int, CaseIterable, Identifiable {
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case fortyFiveMinutes = 45
    case sixtyMinutes = 60
    case ninetyMinutes = 90

    var id: Int { rawValue }

    var title: String {
        L10n.format("ui.sleep_timer.minutes_later", rawValue)
    }

    var duration: TimeInterval {
        TimeInterval(rawValue * 60)
    }
}
