import Foundation

/// Metadata embedded in the AMLL TTML header. It lets the loader reject a
/// document that was keyed to the wrong track before it can win priority.
struct AMLLLyricMetadata: Sendable {
    let ncmMusicID: Int?
    let qqMusicID: Int64?
    let musicName: String?
    let artists: String?
    let album: String?

    init?(ttml: String) {
        guard let root = TTMLDocument.parse(ttml) else { return nil }

        var values: [String: String] = [:]
        for node in root.descendants(where: { $0.localName == "meta" }) {
            guard let key = node.attribute("key"),
                  let value = node.attribute("value") else {
                continue
            }
            values[key] = value
        }

        ncmMusicID = values["ncmMusicId"].flatMap(Int.init)
        qqMusicID = values["qqMusicId"].flatMap(Int64.init)
        musicName = Self.nonempty(values["musicName"])
        artists = Self.nonempty(values["artists"])
        album = Self.nonempty(values["album"])
    }

    func matches(song: LyricsSongMetadata) -> Bool {
        if let ncmMusicID, ncmMusicID != song.id {
            return false
        }

        let musicName = musicName.map(Self.normalized) ?? ""
        let artists = artists.map(Self.normalized) ?? ""

        // Documents without embedded names were produced by older AMLL
        // versions; the server-side ID lookup is the only signal available.
        guard !musicName.isEmpty || !artists.isEmpty else {
            return true
        }

        let songTitle = Self.normalized(song.title)
        let cleanedSongTitle = Self.normalized(
            Self.removingParentheticalContent(from: song.title)
        )

        var titlesMatch = false
        if !musicName.isEmpty {
            let cleanedMusicName = Self.normalized(
                Self.removingParentheticalContent(from: musicName)
            )
            titlesMatch = Self.roughlyMatches(
                songTitle,
                musicName
            ) || (!cleanedSongTitle.isEmpty
                && Self.roughlyMatches(cleanedSongTitle, cleanedMusicName))
        }

        let artistsMatch = artists.isEmpty
            || song.artist.isEmpty
            || Self.sharesArtist(artists, with: song.artist)

        // The NetEase ID embedded in the document is the strongest signal.
        // When both names are available, require at least one of title or
        // artist to agree so a document describing a different track cannot
        // win automatic priority.
        if musicName.isEmpty {
            return artistsMatch
        }
        if artists.isEmpty {
            return titlesMatch
        }
        return titlesMatch || artistsMatch
    }

    private static func sharesArtist(
        _ candidate: String,
        with reference: String
    ) -> Bool {
        let candidateNames = Self.artistNames(from: candidate)
        let referenceNames = Self.artistNames(from: reference)
        guard !candidateNames.isEmpty, !referenceNames.isEmpty else {
            return false
        }
        return referenceNames.contains { referenceName in
            candidateNames.contains { candidateName in
                Self.roughlyMatches(candidateName, referenceName)
            }
        }
    }

    private static func roughlyMatches(_ lhs: String, _ rhs: String) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }
        return lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
    }

    private static func artistNames(from source: String) -> [String] {
        let pieces = source.components(
            separatedBy: CharacterSet(
                charactersIn: ",，、/&"
            )
        )
        return pieces.map(Self.normalized).filter { !$0.isEmpty }
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

    nonisolated private static func normalized(_ source: String) -> String {
        let folded = source.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: nil
        )
        return folded.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }.map(String.init).joined()
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
