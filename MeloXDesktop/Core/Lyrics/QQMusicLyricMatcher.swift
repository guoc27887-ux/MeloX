import Foundation

nonisolated enum QQMusicLyricMatcher {
    private static let acceptedDurationDelta = 8

    static func searchQueries(
        for song: LyricsSongMetadata
    ) -> [String] {
        let title = song.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return [] }

        let cleanedTitle = removingParentheticalContent(from: title)
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let primaryArtist = song.artist
            .components(separatedBy: CharacterSet(charactersIn: ",，、/&"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""

        var queries: [String] = []
        if !primaryArtist.isEmpty {
            queries.append("\(title) \(primaryArtist)")
            if !cleanedTitle.isEmpty, cleanedTitle != title {
                queries.append("\(cleanedTitle) \(primaryArtist)")
            }
        }
        queries.append(title)
        if !cleanedTitle.isEmpty, cleanedTitle != title {
            queries.append(cleanedTitle)
        }
        return queries
    }

    /// Picks the candidate that best matches the NetEase song metadata.
    /// Duration alone is never sufficient: a candidate must also have a
    /// compatible title and, when both sides provide artists, a compatible
    /// artist before it is accepted.
    static func bestCandidate(
        in candidates: [QQMusicTrackMatch],
        for song: LyricsSongMetadata
    ) -> QQMusicTrackMatch? {
        let scored = candidates
            .map { (candidate: $0, score: confidence($0, for: song)) }
            .filter { $0.score != nil }
            .sorted { $0.score!.value > $1.score!.value }
        guard let first = scored.first, let score = first.score else {
            return nil
        }
        return isConfident(score) ? first.candidate : nil
    }

    static func isPlausible(
        _ candidate: QQMusicTrackMatch,
        for song: LyricsSongMetadata
    ) -> Bool {
        guard let score = confidence(candidate, for: song) else {
            return false
        }
        return isConfident(score)
    }

    private static func confidence(
        _ candidate: QQMusicTrackMatch,
        for song: LyricsSongMetadata
    ) -> MatchConfidence? {
        let durationDelta = abs(
            candidate.durationSeconds - song.durationSeconds
        )
        guard durationDelta <= acceptedDurationDelta else { return nil }

        let titleScore = titleSimilarity(candidate.title, song: song)
        guard titleScore >= 0.75 else { return nil }

        let artistScore = artistSimilarity(candidate.artist, song: song)
        if !song.artist.isEmpty,
           !candidate.artist.isEmpty,
           artistScore < 0.3 {
            return nil
        }

        let durationScore: Double
        switch durationDelta {
        case 0: durationScore = 1
        case ...2: durationScore = 0.85
        case ...5: durationScore = 0.7
        default: durationScore = 0.5
        }

        let albumScore = albumSimilarity(candidate.album, song: song)
        let value = titleScore * 0.45
            + artistScore * 0.30
            + durationScore * 0.15
            + albumScore * 0.10
        return MatchConfidence(value: value)
    }

    private static func isConfident(_ confidence: MatchConfidence) -> Bool {
        confidence.value >= 0.66
    }

    private static func titleSimilarity(
        _ candidateTitle: String,
        song: LyricsSongMetadata
    ) -> Double {
        let candidate = normalized(candidateTitle)
        guard !candidate.isEmpty else { return 0 }
        let title = normalized(song.title)
        guard !title.isEmpty else { return 0 }

        if candidate == title { return 1 }
        let candidateCleaned = normalized(
            removingParentheticalContent(from: candidateTitle)
        )
        let titleCleaned = normalized(
            removingParentheticalContent(from: song.title)
        )
        if !candidateCleaned.isEmpty,
           !titleCleaned.isEmpty,
           candidateCleaned == titleCleaned {
            return 0.95
        }
        if title.contains(candidate) || candidate.contains(title)
            || (!titleCleaned.isEmpty
                && (titleCleaned.contains(candidate)
                    || candidate.contains(titleCleaned))) {
            return 0.88
        }
        return 0.4
    }

    private static func artistSimilarity(
        _ candidateArtist: String,
        song: LyricsSongMetadata
    ) -> Double {
        let candidateNames = artistNames(from: candidateArtist)
        let songNames = artistNames(from: song.artist)

        if songNames.isEmpty {
            return 0.5
        }
        if candidateNames.isEmpty {
            return 0.25
        }
        if songNames.contains(where: { songName in
            candidateNames.contains(where: { candidateName in
                songName == candidateName
                    || songName.contains(candidateName)
                    || candidateName.contains(songName)
            })
        }) {
            return 1
        }
        return 0.15
    }

    private static func albumSimilarity(
        _ candidateAlbum: String,
        song: LyricsSongMetadata
    ) -> Double {
        let candidate = normalized(candidateAlbum)
        let album = normalized(song.album)
        guard !candidate.isEmpty, !album.isEmpty else { return 0.5 }
        if candidate == album { return 1 }
        return candidate.contains(album) || album.contains(candidate)
            ? 0.9
            : 0.35
    }

    private static func artistNames(from source: String) -> [String] {
        source.components(
            separatedBy: CharacterSet(charactersIn: ",，、/&")
        )
        .map(normalized)
        .filter { !$0.isEmpty }
    }

    private static func removingParentheticalContent(
        from source: String
    ) -> String {
        source.replacingOccurrences(
            of: #"[\(（\[【][^\)）\]】]*[\)）\]】]"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func normalized(_ source: String) -> String {
        let folded = source.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: nil
        )
        return folded.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }.map(String.init).joined()
    }
}

private struct MatchConfidence {
    let value: Double
}
