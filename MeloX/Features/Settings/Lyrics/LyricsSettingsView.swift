import SwiftUI

struct LyricsSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    LyricsAppearanceSettingsView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ui.settings.lyrics.appearance.title")
                            Text("ui.settings.lyrics.appearance.subtitle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "textformat.size")
                    }
                }

                NavigationLink {
                    LyricsContentSettingsView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ui.settings.lyrics.content.title")
                            Text("ui.settings.lyrics.content.subtitle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "character.book.closed")
                    }
                }

                NavigationLink {
                    LyricsInteractionSettingsView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ui.settings.lyrics.interaction.title")
                            Text("ui.settings.lyrics.interaction.subtitle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "hand.tap")
                    }
                }

                NavigationLink {
                    LyricsAnimationSettingsView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ui.settings.lyrics.animation.title")
                            Text("ui.settings.lyrics.animation.subtitle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                }
            } header: {
                Text("ui.settings.lyrics.section.portrait")
            } footer: {
                Text(
                    L10n.format(
                        "ui.settings.lyrics.footer",
                        settings.lyricsStyle.title
                    )
                )
            }
        }
        .navigationTitle("ui.settings.lyrics.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
