import SwiftUI

struct DesktopLyricsInteractionSettingsView: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        ScrollView {
            Form {
                Section {
                    Toggle(
                        "ui.settings.lyrics.interaction.tap_to_seek",
                        isOn: $settings.lyricsTapToSeek
                    )
                    Toggle(
                        "ui.settings.lyrics.interaction.auto_follow",
                        isOn: $settings.lyricsAutoFollow
                    )

                    if settings.lyricsAutoFollow {
                        HStack {
                            Text("ui.settings.lyrics.interaction.follow_delay")
                            Slider(
                                value: $settings.lyricsFollowDelay,
                                in: 1...10,
                                step: 1
                            )
                            Text(L10n.format("ui.common.seconds", Int(settings.lyricsFollowDelay)))
                                .monospacedDigit()
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                } header: {
                    Text("ui.settings.lyrics.interaction.section.browse_seek")
                } footer: {
                    Text("ui.settings.lyrics.interaction.auto_follow.footer")
                }

                Section("ui.settings.lyrics.interaction.section.sync") {
                    HStack {
                        Text("ui.settings.lyrics.interaction.advance_time")
                        Slider(
                            value: $settings.lyricsAdvanceTime,
                            in: AppSettings.lyricsAdvanceTimeRange,
                            step: 0.1
                        )
                        Text(L10n.format("ui.common.seconds_decimal", settings.lyricsAdvanceTime))
                        .monospacedDigit()
                        .frame(width: 60, alignment: .trailing)
                    }

                    Toggle(
                        "ui.settings.lyrics.interaction.advance_word_by_word",
                        isOn:
                            $settings
                                .lyricsAdvanceTimeAppliesToWordByWord
                    )
                }
            }
            .formStyle(.columns)
            .padding()
        }
        .scrollIndicators(.automatic)
    }
}
