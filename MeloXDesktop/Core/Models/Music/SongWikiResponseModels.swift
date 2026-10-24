import Foundation

struct SongWikiResponse: Decodable {
    let code: Int
    let data: SongWikiPayload?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, data, message, msg
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 200
        data = try container.decodeIfPresent(
            SongWikiPayload.self,
            forKey: .data
        )
        message =
            try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .msg)
    }
}

struct SongWikiPayload: Decodable {
    let blocks: [SongWikiBlock]

    enum CodingKeys: String, CodingKey {
        case blocks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blocks =
            (try? container.decodeIfPresent(
                [SongWikiBlock].self,
                forKey: .blocks
            )) ?? []
    }
}

struct SongWikiBlock: Decodable {
    let code: String
    let uiElement: SongWikiUIElement?
    let creatives: [SongWikiCreative]

    enum CodingKeys: String, CodingKey {
        case code, uiElement, creatives
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(
            String.self,
            forKey: .code
        ) ?? "SONG_PLAY_ABOUT_UNKNOWN"
        uiElement = try? container.decodeIfPresent(
            SongWikiUIElement.self,
            forKey: .uiElement
        )
        creatives =
            (try? container.decodeIfPresent(
                [SongWikiCreative].self,
                forKey: .creatives
            )) ?? []
    }

    var resources: [SongWikiResource] {
        creatives.flatMap(\.resources)
    }
}

struct SongWikiCreative: Decodable {
    let creativeType: String?
    let uiElement: SongWikiUIElement?
    let resources: [SongWikiResource]

    enum CodingKeys: String, CodingKey {
        case creativeType, uiElement, resources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        creativeType = try container.decodeIfPresent(
            String.self,
            forKey: .creativeType
        )
        uiElement = try? container.decodeIfPresent(
            SongWikiUIElement.self,
            forKey: .uiElement
        )
        resources =
            (try? container.decodeIfPresent(
                [SongWikiResource].self,
                forKey: .resources
            )) ?? []
    }
}

struct SongWikiResource: Decodable {
    let resourceType: String?
    let resourceID: String?
    let uiElement: SongWikiUIElement?
    let extensionInfo: SongWikiResourceExtension?

    enum CodingKeys: String, CodingKey {
        case resourceType, resourceId, uiElement, resourceExt
        case resourceExtInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resourceType = try container.decodeIfPresent(
            String.self,
            forKey: .resourceType
        )
        resourceID = Self.decodeString(
            from: container,
            forKey: .resourceId
        )
        uiElement = try? container.decodeIfPresent(
            SongWikiUIElement.self,
            forKey: .uiElement
        )
        extensionInfo =
            (try? container.decodeIfPresent(
                SongWikiResourceExtension.self,
                forKey: .resourceExt
            ))
            ?? (try? container.decodeIfPresent(
                SongWikiResourceExtension.self,
                forKey: .resourceExtInfo
            ))
    }

    private static func decodeString(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String? {
        if let value = try? container.decode(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int64.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}

struct SongWikiUIElement: Decodable {
    let mainTitle: SongWikiTitle?
    let subTitles: [SongWikiTitle]
    let images: [SongWikiImage]
    let textLinks: [SongWikiTextLink]
    let descriptions: [SongWikiDescription]
    let buttons: [SongWikiButton]

    enum CodingKeys: String, CodingKey {
        case mainTitle, subTitle, subTitles, images, textLinks
        case descriptions, buttons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mainTitle = try? container.decodeIfPresent(
            SongWikiTitle.self,
            forKey: .mainTitle
        )

        var decodedSubTitles =
            (try? container.decodeIfPresent(
                [SongWikiTitle].self,
                forKey: .subTitles
            )) ?? []
        if decodedSubTitles.isEmpty,
           let subTitle = try? container.decodeIfPresent(
               SongWikiTitle.self,
               forKey: .subTitle
           ) {
            decodedSubTitles = [subTitle]
        }
        subTitles = decodedSubTitles

        images =
            (try? container.decodeIfPresent(
                [SongWikiImage].self,
                forKey: .images
            )) ?? []
        textLinks =
            (try? container.decodeIfPresent(
                [SongWikiTextLink].self,
                forKey: .textLinks
            )) ?? []
        descriptions =
            (try? container.decodeIfPresent(
                [SongWikiDescription].self,
                forKey: .descriptions
            )) ?? []
        buttons =
            (try? container.decodeIfPresent(
                [SongWikiButton].self,
                forKey: .buttons
            )) ?? []
    }
}

struct SongWikiTitle: Decodable {
    let title: String?
}

struct SongWikiImage: Decodable {
    let title: String?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case title
        case imageURL = "imageUrl"
    }
}

struct SongWikiTextLink: Decodable {
    let text: String?
    let url: String?
}

struct SongWikiDescription: Decodable {
    let description: String?
}

struct SongWikiButton: Decodable {
    let text: String?
}

struct SongWikiResourceExtension: Decodable {
    let playCount: Int?
    let musicFirstListen: SongWikiFirstListen?
    let musicTotalPlay: SongWikiTotalPlay?

    enum CodingKeys: String, CodingKey {
        case playCount
        case musicFirstListen = "musicFirstListenDto"
        case musicTotalPlay = "musicTotalPlayDto"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playCount = decodeFlexibleInt(
            from: container,
            forKey: .playCount
        )
        musicFirstListen = try? container.decodeIfPresent(
            SongWikiFirstListen.self,
            forKey: .musicFirstListen
        )
        musicTotalPlay = try? container.decodeIfPresent(
            SongWikiTotalPlay.self,
            forKey: .musicTotalPlay
        )
    }
}

struct SongWikiFirstListen: Decodable {
    let date: String?
}

struct SongWikiTotalPlay: Decodable {
    let playCount: Int?
    let duration: Int?
    let text: String?

    enum CodingKeys: String, CodingKey {
        case playCount, duration, text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playCount = decodeFlexibleInt(
            from: container,
            forKey: .playCount
        )
        duration = decodeFlexibleInt(
            from: container,
            forKey: .duration
        )
        text = try container.decodeIfPresent(
            String.self,
            forKey: .text
        )
    }
}

private func decodeFlexibleInt<Key: CodingKey>(
    from container: KeyedDecodingContainer<Key>,
    forKey key: Key
) -> Int? {
    if let value = try? container.decode(Int.self, forKey: key) {
        return value
    }
    if let value = try? container.decode(Double.self, forKey: key) {
        return Int(value)
    }
    if let value = try? container.decode(String.self, forKey: key) {
        return Int(value)
    }
    return nil
}
