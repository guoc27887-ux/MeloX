import SwiftUI

struct DesktopSleepTimerView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private let choices: [(String, TimeInterval)] = [
        (L10n.format("ui.desktop.sleep_timer.minutes", 15), 15 * 60),
        (L10n.format("ui.desktop.sleep_timer.minutes", 30), 30 * 60),
        (L10n.format("ui.desktop.sleep_timer.minutes", 45), 45 * 60),
        (L10n.format("ui.desktop.sleep_timer.hours", 1), 60 * 60),
        (L10n.format("ui.desktop.sleep_timer.hours", 2), 120 * 60),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("ui.sleep_timer.title")
                .font(.title.bold())

            if let endDate = model.player.sleepTimer.endDate {
                Label(
                    L10n.format(
                        "ui.desktop.sleep_timer.stop_at",
                        endDate.formatted(
                            Date.FormatStyle(date: .omitted, time: .shortened)
                                .locale(L10n.locale)
                        )
                    ),
                    systemImage: "moon.zzz.fill"
                )
                .foregroundStyle(.secondary)
            }

            ForEach(choices, id: \.1) { choice in
                Button(choice.0) {
                    model.player.sleepTimer.start(duration: choice.1)
                    dismiss()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }

            if model.player.sleepTimer.isActive {
                Button("ui.sleep_timer.cancel", role: .destructive) {
                    model.player.sleepTimer.cancel()
                    dismiss()
                }
            }
        }
        .padding(28)
        .frame(width: 360)
    }
}
