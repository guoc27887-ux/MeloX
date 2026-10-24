import SwiftUI

struct PodcastProgramDetailView: View {
    let program: PodcastProgram

    @Environment(PlayerStore.self) private var player

    var body: some View {
        List {
            header

            Section("ui.common.podcast") {
                NavigationLink(
                    value: MusicRoute.podcast(
                        program.podcastSummary
                    )
                ) {
                    LabeledContent(
                        L10n.string("ui.podcasts.from"),
                        value: program.radio.name
                    )
                }
            }

            Section("ui.podcasts.episode_information") {
                if let createTime = program.createTime {
                    LabeledContent(
                        L10n.string("ui.song.release_date"),
                        value: createTime.podcastDateText
                    )
                }

                if program.durationMS > 0 {
                    LabeledContent(
                        L10n.string("ui.common.duration"),
                        value: program.durationMS.podcastDurationText
                    )
                }

                if program.listenerCount > 0 {
                    LabeledContent(
                        L10n.string("ui.common.plays"),
                        value:
                            L10n.format("ui.common.times_compact", program.listenerCount.podcastCountText)
                    )
                }

                if program.likedCount > 0 {
                    LabeledContent(
                        L10n.string("ui.common.likes"),
                        value: program.likedCount.podcastCountText
                    )
                }

                if program.commentCount > 0 {
                    LabeledContent(
                        L10n.string("ui.comments.title"),
                        value: program.commentCount.podcastCountText
                    )
                }
            }

            if let description = program
                .programDescription?
                .podcastNonempty {
                Section("ui.podcasts.episode_description") {
                    Text(description)
                        .textSelection(.enabled)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("ui.podcasts.episode")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        Section {
            VStack(spacing: 16) {
                ArtworkImage(
                    url: program.artworkURL,
                    cornerRadius: 14
                )
                .frame(width: 210, height: 210)
                .shadow(
                    color: .black.opacity(0.17),
                    radius: 16,
                    y: 8
                )

                Text(program.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                if let hostName = program.host?.nickname {
                    Text(hostName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button(action: play) {
                    Label(
                        isCurrent && player.isPlaying
                            ? L10n.string("ui.player.pause")
                            : L10n.string("ui.podcasts.play_episode"),
                        systemImage:
                            isCurrent && player.isPlaying
                            ? "pause.fill"
                            : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(program.playbackSong == nil)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var isCurrent: Bool {
        guard let song = program.playbackSong else { return false }
        return player.currentSong?.id == song.id
    }

    private func play() {
        guard let song = program.playbackSong else { return }
        if isCurrent {
            player.togglePlayback()
            return
        }

        Task {
            await player.play(
                song,
                in: [song],
                sourceID: program.radio.id
            )
        }
    }
}
