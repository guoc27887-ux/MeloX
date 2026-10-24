import Foundation

func filterLibraryPlaylists(
    _ playlists: [Playlist],
    query: String
) -> [Playlist] {
    let query = normalizedLibrarySearchQuery(query)
    guard !query.isEmpty else { return playlists }

    return playlists.filter { playlist in
        librarySearchMatches(
            query,
            fields: [
                playlist.name,
                playlist.creator?.nickname,
                playlist.playlistDescription,
                playlist.copywriter,
            ]
        )
    }
}

func filterLibraryPodcasts(
    _ podcasts: [Podcast],
    query: String
) -> [Podcast] {
    let query = normalizedLibrarySearchQuery(query)
    guard !query.isEmpty else { return podcasts }

    return podcasts.filter { podcast in
        librarySearchMatches(
            query,
            fields: [
                podcast.name,
                podcast.host?.nickname,
                podcast.category,
                podcast.secondCategory,
                podcast.podcastDescription,
                podcast.recommendationText,
            ]
        )
    }
}

func filterCloudSongs(
    _ items: [CloudSong],
    query: String
) -> [CloudSong] {
    let query = normalizedLibrarySearchQuery(query)
    guard !query.isEmpty else { return items }

    return items.filter { item in
        librarySearchMatches(
            query,
            fields: [
                item.songName,
                item.artist,
                item.album,
                item.simpleSong.name,
                item.simpleSong.artistText,
                item.simpleSong.album?.name,
            ]
        )
    }
}

func normalizedLibrarySearchQuery(_ query: String) -> String {
    query.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func librarySearchMatches(
    _ query: String,
    fields: [String?]
) -> Bool {
    fields.contains { field in
        field?.localizedCaseInsensitiveContains(query) == true
    }
}
