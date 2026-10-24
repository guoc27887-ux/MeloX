import Foundation

struct SongWiki {
    let memories: [SongWikiMemoryItem]
    let tagGroups: [SongWikiTagGroup]
    let attributes: [SongWikiAttribute]
    let associationGroups: [SongWikiAssociationGroup]
    let reviews: [SongWikiReview]
    let similarSongs: [SongWikiSongReference]
    let relatedPlaylists: [SongWikiPlaylistReference]
    let contributionURL: URL?

    var isEmpty: Bool {
        memories.isEmpty
            && tagGroups.isEmpty
            && attributes.isEmpty
            && associationGroups.isEmpty
            && reviews.isEmpty
            && similarSongs.isEmpty
            && relatedPlaylists.isEmpty
            && contributionURL == nil
    }

    init(payload: SongWikiPayload) {
        let basicBlockCodes: Set<String> = [
            "SONG_PLAY_ABOUT_SONG_BASIC",
            "SONG_PLAY_ABOUT_MUSIC_SONG_GRADE",
        ]
        let basicBlocks = payload.blocks.filter {
            basicBlockCodes.contains($0.code)
        }

        var decodedTagGroups: [SongWikiTagGroup] = []
        var decodedAttributes: [SongWikiAttribute] = []
        var decodedAssociations: [SongWikiAssociationGroup] = []
        var decodedReviews: [SongWikiReview] = []

        for (blockIndex, block) in basicBlocks.enumerated() {
            for (creativeIndex, creative) in block.creatives.enumerated() {
                let creativeID =
                    "\(block.code)-\(blockIndex)-\(creativeIndex)"
                let creativeType =
                    creative.creativeType?.lowercased() ?? ""
                let title =
                    creative.uiElement?.mainTitle?.title?.nonempty
                    ?? L10n.string("ui.song.wiki.information")

                switch creativeType {
                case "songtag", "songbiztag":
                    let values = Self.unique(
                        creative.resources.compactMap {
                            $0.uiElement?.mainTitle?.title?.nonempty
                        } + (creative.uiElement?.textValues ?? [])
                    )
                    if !values.isEmpty {
                        decodedTagGroups.append(
                            SongWikiTagGroup(
                                id: creativeID,
                                title: title,
                                values: values
                            )
                        )
                    }

                case "songcomment":
                    decodedReviews.append(
                        contentsOf: creative.resources.enumerated()
                            .compactMap { index, resource in
                                guard let body =
                                    resource.uiElement?
                                        .descriptionValues.first else {
                                    return nil
                                }
                                return SongWikiReview(
                                    id: "\(creativeID)-\(index)",
                                    attribution:
                                        resource.uiElement?
                                            .mainTitle?.title?.nonempty,
                                    body: body
                                )
                            }
                    )

                case "sheet":
                    let values =
                        creative.uiElement?.buttonValues
                        ?? []
                    let fallback = creative.resources.isEmpty
                        ? []
                        : [L10n.format("ui.song.wiki.resource_count", creative.resources.count)]
                    if let value = (values + fallback).first {
                        decodedAttributes.append(
                            SongWikiAttribute(
                                id: creativeID,
                                title: title,
                                value: value
                            )
                        )
                    }

                default:
                    let details = Self.details(
                        from: creative.resources,
                        idPrefix: creativeID
                    )
                    if !details.isEmpty {
                        decodedAssociations.append(
                            SongWikiAssociationGroup(
                                id: creativeID,
                                title: title,
                                countText:
                                    creative.uiElement?
                                        .buttonValues.first,
                                details: details
                            )
                        )
                    } else {
                        let values = Self.unique(
                            (creative.uiElement?.textValues ?? [])
                                + (creative.uiElement?.buttonValues ?? [])
                        )
                        if !values.isEmpty {
                            decodedAttributes.append(
                                SongWikiAttribute(
                                    id: creativeID,
                                    title: title,
                                    value: L10n.joined(
                                        values,
                                        separatorKey:
                                            "ui.common.compact_list_separator"
                                    )
                                )
                            )
                        }
                    }
                }
            }
        }

        memories = Self.memories(from: payload.blocks)
        tagGroups = decodedTagGroups
        attributes = decodedAttributes
        associationGroups = decodedAssociations
        reviews = decodedReviews
        similarSongs = Self.similarSongs(from: payload.blocks)
        relatedPlaylists = Self.relatedPlaylists(from: payload.blocks)
        contributionURL = basicBlocks.lazy
            .flatMap { $0.uiElement?.textLinks ?? [] }
            .compactMap { Self.officialURL(from: $0.url) }
            .first
    }

    private static func memories(
        from blocks: [SongWikiBlock]
    ) -> [SongWikiMemoryItem] {
        let resources = blocks
            .filter { $0.code == "SONG_PLAY_ABOUT_MUSIC_MEMORY" }
            .flatMap(\.resources)

        return resources.enumerated().compactMap { index, resource in
            switch resource.resourceType?.uppercased() {
            case "FIRST_LISTEN":
                guard let date = resource.extensionInfo?
                    .musicFirstListen?.date?.nonempty else {
                    return nil
                }
                return SongWikiMemoryItem(
                    id: "first-listen-\(index)",
                    title: L10n.string("ui.song.wiki.first_listen"),
                    value: date
                )

            case "TOTAL_PLAY":
                guard let totalPlay = resource.extensionInfo?
                    .musicTotalPlay else {
                    return nil
                }
                var values: [String] = []
                if let playCount = totalPlay.playCount {
                    values.append(
                        L10n.format(
                            "ui.song.wiki.play_count_value",
                            playCount.formatted(.number.locale(L10n.locale))
                        )
                    )
                }
                if let duration = totalPlay.duration, duration > 0 {
                    values.append(
                        L10n.format(
                            "ui.song.wiki.duration_minutes_value",
                            duration.formatted(.number.locale(L10n.locale))
                        )
                    )
                }
                if let text = totalPlay.text?.nonempty {
                    values.append(text)
                }
                guard !values.isEmpty else { return nil }
                return SongWikiMemoryItem(
                    id: "total-play-\(index)",
                    title: L10n.string("ui.song.wiki.total_play"),
                    value: L10n.joined(
                        values,
                        separatorKey: "ui.common.metadata_separator"
                    )
                )

            default:
                return nil
            }
        }
    }

    private static func details(
        from resources: [SongWikiResource],
        idPrefix: String
    ) -> [SongWikiAssociationDetail] {
        resources.enumerated().compactMap { index, resource in
            detail(
                from: resource.uiElement,
                id: "\(idPrefix)-\(index)"
            )
        }
    }

    private static func detail(
        from uiElement: SongWikiUIElement?,
        id: String
    ) -> SongWikiAssociationDetail? {
        guard let uiElement else { return nil }
        let title = uiElement.mainTitle?.title?.nonempty
        let subtitleValues = Self.unique(
            uiElement.subTitles.compactMap(\.title?.nonempty)
                + uiElement.textValues
        )
        let body = uiElement.descriptionValues.joined(separator: "\n")
        guard title != nil || !subtitleValues.isEmpty || !body.isEmpty else {
            return nil
        }
        return SongWikiAssociationDetail(
            id: id,
            title: title,
            subtitle: subtitleValues.isEmpty
                ? nil
                : L10n.joined(
                    subtitleValues,
                    separatorKey: "ui.common.metadata_separator"
                ),
            body: body.nonempty
        )
    }

    private static func similarSongs(
        from blocks: [SongWikiBlock]
    ) -> [SongWikiSongReference] {
        let resources = blocks
            .filter { $0.code == "SONG_PLAY_ABOUT_SIMILAR_SONG" }
            .flatMap(\.resources)
        var seen: Set<Int> = []
        return resources.compactMap { resource in
            guard resource.resourceType?.lowercased() == "song",
                  let rawID = resource.resourceID,
                  let id = Int(rawID),
                  id > 0,
                  seen.insert(id).inserted,
                  let title =
                      resource.uiElement?
                          .mainTitle?.title?.nonempty else {
                return nil
            }
            return SongWikiSongReference(
                id: id,
                title: title,
                artist:
                    resource.uiElement?.subTitles
                        .compactMap(\.title?.nonempty)
                        .joined(
                            separator: L10n.string(
                                "ui.common.artist_separator"
                            )
                        )
                        .nonempty,
                note:
                    resource.uiElement?
                        .descriptionValues.first,
                artworkURLString:
                    resource.uiElement?
                        .images.first?.imageURL
            )
        }
    }

    private static func relatedPlaylists(
        from blocks: [SongWikiBlock]
    ) -> [SongWikiPlaylistReference] {
        let resources = blocks
            .filter { $0.code == "SONG_PLAY_ABOUT_RELATED_PLAYLIST" }
            .flatMap(\.resources)
        var seen: Set<Int> = []
        return resources.compactMap { resource in
            guard resource.resourceType?.lowercased() == "playlist",
                  let rawID = resource.resourceID,
                  let id = Int(rawID),
                  id > 0,
                  seen.insert(id).inserted,
                  let title =
                      resource.uiElement?
                          .mainTitle?.title?.nonempty else {
                return nil
            }
            return SongWikiPlaylistReference(
                id: id,
                title: title,
                artworkURLString:
                    resource.uiElement?
                        .images.first?.imageURL,
                playCount: resource.extensionInfo?.playCount ?? 0
            )
        }
    }

    private static func officialURL(from source: String?) -> URL? {
        guard let source = source?.nonempty,
              var components = URLComponents(string: source),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }
        if scheme == "http" {
            components.scheme = "https"
        }
        return components.url
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }
}

struct SongWikiMemoryItem: Identifiable {
    let id: String
    let title: String
    let value: String
}

struct SongWikiTagGroup: Identifiable {
    let id: String
    let title: String
    let values: [String]
}

struct SongWikiAttribute: Identifiable {
    let id: String
    let title: String
    let value: String
}

struct SongWikiAssociationGroup: Identifiable {
    let id: String
    let title: String
    let countText: String?
    let details: [SongWikiAssociationDetail]
}

struct SongWikiAssociationDetail: Identifiable {
    let id: String
    let title: String?
    let subtitle: String?
    let body: String?
}

struct SongWikiReview: Identifiable {
    let id: String
    let attribution: String?
    let body: String
}

struct SongWikiSongReference: Identifiable, Hashable {
    let id: Int
    let title: String
    let artist: String?
    let note: String?
    let artworkURLString: String?

    var artworkURL: URL? {
        makeArtworkURL(from: artworkURLString, dimension: 160)
    }
}

struct SongWikiPlaylistReference: Identifiable {
    let id: Int
    let title: String
    let artworkURLString: String?
    let playCount: Int

    var artworkURL: URL? {
        makeArtworkURL(from: artworkURLString, dimension: 160)
    }

    var playlist: Playlist {
        Playlist(
            id: id,
            name: title,
            coverURLString: artworkURLString,
            playCount: playCount
        )
    }
}

private extension SongWikiUIElement {
    var textValues: [String] {
        textLinks.compactMap(\.text?.nonempty)
    }

    var descriptionValues: [String] {
        descriptions.compactMap(\.description?.nonempty)
    }

    var buttonValues: [String] {
        buttons.compactMap(\.text?.nonempty)
    }
}

private extension String {
    var nonempty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
