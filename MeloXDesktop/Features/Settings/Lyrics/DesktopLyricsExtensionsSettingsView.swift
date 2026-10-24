import SwiftUI

struct DesktopLyricsExtensionsSettingsView: View {
    @Environment(DesktopAppModel.self) private var model
    @State private var showsNotificationPermissionAlert = false

    var body: some View {
        @Bindable var floating = model.settings.floatingLyrics
        @Bindable var notifications = model.settings.lyricsNotifications

        ScrollView {
            Form {
                Section("ui.floating_lyrics.title") {
                    Toggle(
                        "ui.settings.floating_lyrics.show_translation",
                        isOn: $floating.showsTranslation
                    )
                    Toggle(
                        "ui.settings.floating_lyrics.show_next",
                        isOn: $floating.showsNextLine
                    )
                    Picker(
                        "ui.desktop.floating_lyrics.text_alignment",
                        selection: $floating.textAlignment
                    ) {
                        ForEach(FloatingLyricsTextAlignment.allCases) {
                            alignment in
                            Text(alignment.title)
                                .tag(alignment)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("ui.desktop.floating_lyrics.text_style") {
                    Picker("ui.settings.lyrics.appearance.font_weight", selection: $floating.fontWeight) {
                        ForEach(LyricsFontWeight.allCases) { weight in
                            Text(weight.title)
                                .tag(weight)
                        }
                    }
                    Picker("ui.desktop.floating_lyrics.text_effect", selection: $floating.textEffect) {
                        ForEach(FloatingLyricsTextEffect.allCases) { effect in
                            Text(effect.title)
                                .tag(effect)
                        }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text("ui.settings.floating_lyrics.text_size")
                        Slider(
                            value: $floating.fontScale,
                            in: FloatingLyricsPreferences.fontScaleRange,
                            step: 0.05
                        )
                        Text(
                            L10n.percent(floating.fontScale)
                        )
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                    }
                    percentageSlider(
                        L10n.string("ui.desktop.floating_lyrics.text_opacity"),
                        value: $floating.textOpacity,
                        range: FloatingLyricsPreferences.textOpacityRange
                    )
                    valueSlider(
                        L10n.string("ui.settings.lyrics.appearance.line_spacing"),
                        value: $floating.lineSpacing,
                        range: FloatingLyricsPreferences.lineSpacingRange,
                        suffix: " pt"
                    )
                }

                Section("ui.desktop.floating_lyrics.background") {
                    Picker("ui.settings.player_appearance.background_style", selection: $floating.backgroundStyle) {
                        ForEach(FloatingLyricsBackgroundStyle.allCases) {
                            style in
                            Text(style.title)
                                .tag(style)
                        }
                    }
                    percentageSlider(
                        L10n.string("ui.desktop.floating_lyrics.background_intensity"),
                        value: $floating.backgroundOpacity,
                        range: FloatingLyricsPreferences.backgroundOpacityRange
                    )
                    .disabled(floating.backgroundStyle == .transparent)
                    if floating.backgroundStyle == .blurredArtwork {
                        valueSlider(
                            L10n.string("ui.desktop.floating_lyrics.artwork_blur"),
                            value: $floating.backgroundBlur,
                            range: FloatingLyricsPreferences.backgroundBlurRange,
                            suffix: " pt"
                        )
                    }
                    valueSlider(
                        L10n.string("ui.desktop.floating_lyrics.corner_radius"),
                        value: $floating.cornerRadius,
                        range: FloatingLyricsPreferences.cornerRadiusRange,
                        suffix: " pt"
                    )
                    LabeledContent("ui.desktop.floating_lyrics.window_size") {
                        Text("ui.desktop.floating_lyrics.resize_hint")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("ui.settings.lyrics_notification.title") {
                    Toggle(
                        "ui.desktop.lyrics_notifications.enable",
                        isOn: notificationEnabledBinding
                    )
                    Toggle(
                        "ui.settings.lyrics_notification.show_artwork",
                        isOn: $notifications.showsArtwork
                    )
                    Toggle(
                        "ui.settings.lyrics_notification.show_foreground",
                        isOn: $notifications.showsInForeground
                    )
                    Toggle(
                        "ui.settings.lyrics_notification.show_background",
                        isOn: $notifications.showsInBackground
                    )
                    Toggle(
                        "ui.settings.lyrics_notification.dismiss_on_pause",
                        isOn: $notifications.removesWhenPaused
                    )
                }
            }
            .formStyle(.columns)
            .padding()
        }
        .scrollIndicators(.automatic)
        .onChange(of: notifications.showsArtwork) { _, _ in
            model.player.applyLyricsNotificationPreference()
        }
        .onChange(of: notifications.showsInForeground) { _, _ in
            model.player.applyLyricsNotificationPreference()
        }
        .onChange(of: notifications.showsInBackground) { _, _ in
            model.player.applyLyricsNotificationPreference()
        }
        .onChange(of: notifications.removesWhenPaused) { _, _ in
            model.player.applyLyricsNotificationPreference()
        }
        .alert(
            L10n.string("ui.settings.lyrics_notification.enable_failed.title"),
            isPresented: $showsNotificationPermissionAlert
        ) {
            Button("ui.common.ok", role: .cancel) {}
        } message: {
            Text("ui.settings.lyrics_notification.permission_required")
        }
    }

    private func percentageSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack {
            Text(title)
            Slider(value: value, in: range, step: 0.05)
            Text(L10n.percent(value.wrappedValue))
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
        }
    }

    private func valueSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String
    ) -> some View {
        HStack {
            Text(title)
            Slider(value: value, in: range, step: 1)
            Text(L10n.format("ui.common.points", Int(value.wrappedValue.rounded())))
                .monospacedDigit()
                .frame(width: 56, alignment: .trailing)
        }
    }

    private var notificationEnabledBinding: Binding<Bool> {
        Binding(
            get: {
                model.settings.lyricsNotifications.isEnabled
            },
            set: { isEnabled in
                if !isEnabled {
                    model.settings.lyricsNotifications.isEnabled = false
                    model.player.applyLyricsNotificationPreference()
                    return
                }

                Task { @MainActor in
                    guard await model.lyricsNotifications
                        .requestAuthorization() else {
                        model.settings.lyricsNotifications.isEnabled = false
                        showsNotificationPermissionAlert = true
                        return
                    }
                    model.settings.lyricsNotifications.isEnabled = true
                    model.player.applyLyricsNotificationPreference()
                }
            }
        )
    }
}
