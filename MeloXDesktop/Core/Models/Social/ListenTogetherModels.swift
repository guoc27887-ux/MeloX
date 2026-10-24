import Foundation

struct ListenTogetherUser: Decodable, Hashable, Identifiable {
    let id: String
    let nickname: String
    let avatarURLString: String?

    var avatarURL: URL? {
        makeArtworkURL(from: avatarURLString, dimension: 160)
    }

    private enum CodingKeys: String, CodingKey {
        case id = "userId"
        case nickname
        case avatarURLString = "avatarUrl"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(
            ListenTogetherIdentifier.self,
            forKey: .id
        ))?.rawValue ?? ""
        nickname = try container.decodeIfPresent(
            String.self,
            forKey: .nickname
        ) ?? L10n.string("ui.metadata.netease_user")
        avatarURLString = try container.decodeIfPresent(
            String.self,
            forKey: .avatarURLString
        )
    }
}

struct ListenTogetherRoom: Decodable, Hashable, Identifiable {
    let id: String
    let creatorID: String
    let users: [ListenTogetherUser]
    let roomCreateTime: Int64?
    let effectiveDurationMilliseconds: Int64?

    private enum CodingKeys: String, CodingKey {
        case id = "roomId"
        case creatorID = "creatorId"
        case users = "roomUsers"
        case roomCreateTime
        case effectiveDurationMilliseconds = "effectiveDurationMs"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(
            ListenTogetherIdentifier.self,
            forKey: .id
        ))?.rawValue ?? ""
        creatorID = (try? container.decode(
            ListenTogetherIdentifier.self,
            forKey: .creatorID
        ))?.rawValue ?? ""
        users = try container.decodeIfPresent(
            [ListenTogetherUser].self,
            forKey: .users
        ) ?? []
        roomCreateTime = (try? container.decode(
            ListenTogetherInteger.self,
            forKey: .roomCreateTime
        ))?.value
        effectiveDurationMilliseconds = (try? container.decode(
            ListenTogetherInteger.self,
            forKey: .effectiveDurationMilliseconds
        ))?.value
    }
}

struct ListenTogetherRoomPayload: Decodable {
    let type: String?
    let roomInfo: ListenTogetherRoom?
    let hintText: String?
}

struct ListenTogetherRoomResponse: Decodable {
    let code: Int
    let data: ListenTogetherRoomPayload?
    let message: String?
}

struct ListenTogetherRoomStatusResponse: Decodable {
    let code: Int
    let data: ListenTogetherRoomStatus?
    let message: String?
}

struct ListenTogetherRoomStatus: Decodable {
    let isInRoom: Bool
    let roomInfo: ListenTogetherRoom?
    let status: String?

    private enum CodingKeys: String, CodingKey {
        case isInRoom = "inRoom"
        case roomInfo
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isInRoom = try container.decodeIfPresent(
            Bool.self,
            forKey: .isInRoom
        ) ?? false
        roomInfo = try container.decodeIfPresent(
            ListenTogetherRoom.self,
            forKey: .roomInfo
        )
        status = try container.decodeIfPresent(
            String.self,
            forKey: .status
        )
    }
}

struct ListenTogetherRoomCheckResponse: Decodable {
    let code: Int
    let data: ListenTogetherRoomCheck?
    let message: String?
}

struct ListenTogetherRoomCheck: Decodable {
    let isJoinable: Bool
    let type: String?
    let status: String?

    private enum CodingKeys: String, CodingKey {
        case isJoinable = "joinable"
        case type
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isJoinable = try container.decodeIfPresent(
            Bool.self,
            forKey: .isJoinable
        ) ?? false
        type = try container.decodeIfPresent(String.self, forKey: .type)
        status = try container.decodeIfPresent(
            String.self,
            forKey: .status
        )
    }
}

struct ListenTogetherActionResponse: Decodable {
    let code: Int
    let data: ListenTogetherActionResult?
    let message: String?
}

struct ListenTogetherActionResult: Decodable {
    let result: Bool?
    let timeSpan: Int?
    let success: Bool?
}

struct ListenTogetherPlaybackResponse: Decodable {
    let code: Int
    let data: ListenTogetherPlaybackPayload?
    let message: String?
}

struct ListenTogetherPlaybackPayload: Decodable {
    let playlist: ListenTogetherPlaylistSnapshot?
    let playCommand: ListenTogetherPlayCommand?
}

struct ListenTogetherPlaylistSnapshot: Decodable, Hashable {
    let displayList: ListenTogetherSongList?
    let randomList: ListenTogetherSongList?
    let playMode: String?
    let replace: Bool?
    let versions: [ListenTogetherPlaylistVersion]

    private enum CodingKeys: String, CodingKey {
        case displayList
        case randomList
        case playMode
        case replace
        case versions = "version"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayList = try container.decodeIfPresent(
            ListenTogetherSongList.self,
            forKey: .displayList
        )
        randomList = try container.decodeIfPresent(
            ListenTogetherSongList.self,
            forKey: .randomList
        )
        playMode = try container.decodeIfPresent(
            String.self,
            forKey: .playMode
        )
        replace = try container.decodeIfPresent(
            Bool.self,
            forKey: .replace
        )
        versions = try container.decodeIfPresent(
            [ListenTogetherPlaylistVersion].self,
            forKey: .versions
        ) ?? []
    }

    var playbackSongIDs: [Int] {
        let identifiers: [ListenTogetherIdentifier]
        if isRandomMode,
           let randomResult = randomList?.result,
           !randomResult.isEmpty {
            identifiers = randomResult
        } else {
            identifiers = displayList?.result ?? []
        }

        var seen: Set<Int> = []
        return identifiers.compactMap { identifier in
            guard let id = Int(identifier.rawValue),
                  id > 0,
                  seen.insert(id).inserted else {
                return nil
            }
            return id
        }
    }

    private var isRandomMode: Bool {
        guard let mode = playMode?.uppercased() else {
            return false
        }
        return mode.contains("RANDOM") || mode.contains("SHUFFLE")
    }
}

struct ListenTogetherSongList: Decodable, Hashable {
    let changed: Bool?
    let result: [ListenTogetherIdentifier]
    let recommendedSongIDs: [ListenTogetherIdentifier]

    private enum CodingKeys: String, CodingKey {
        case changed
        case result
        case recommendedSongIDs = "rcmdSongIds"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        changed = try container.decodeIfPresent(
            Bool.self,
            forKey: .changed
        )
        result = try container.decodeIfPresent(
            [ListenTogetherIdentifier].self,
            forKey: .result
        ) ?? []
        recommendedSongIDs = try container.decodeIfPresent(
            [ListenTogetherIdentifier].self,
            forKey: .recommendedSongIDs
        ) ?? []
    }
}

struct ListenTogetherPlaylistVersion: Decodable, Hashable {
    let userID: String
    let version: Int

    private enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case version
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = (try? container.decode(
            ListenTogetherIdentifier.self,
            forKey: .userID
        ))?.rawValue ?? ""
        version = Int(
            (try? container.decode(
                ListenTogetherInteger.self,
                forKey: .version
            ))?.value ?? 0
        )
    }
}

struct ListenTogetherPlayCommand: Decodable, Hashable {
    let userID: String?
    let commandType: String?
    let formerSongID: String?
    let targetSongID: String?
    let progressMilliseconds: Int64
    let playStatus: String?
    let clientSequence: Int64
    let serverSequence: Int64

    private enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case commandType
        case formerSongID = "formerSongId"
        case targetSongID = "targetSongId"
        case progressMilliseconds = "progress"
        case playStatus
        case clientSequence = "clientSeq"
        case serverSequence = "serverSeq"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = (try? container.decode(
            ListenTogetherIdentifier.self,
            forKey: .userID
        ))?.rawValue
        commandType = try container.decodeIfPresent(
            String.self,
            forKey: .commandType
        )
        formerSongID = (try? container.decode(
            ListenTogetherIdentifier.self,
            forKey: .formerSongID
        ))?.rawValue
        targetSongID = (try? container.decode(
            ListenTogetherIdentifier.self,
            forKey: .targetSongID
        ))?.rawValue
        progressMilliseconds = (try? container.decode(
            ListenTogetherInteger.self,
            forKey: .progressMilliseconds
        ))?.value ?? 0
        playStatus = try container.decodeIfPresent(
            String.self,
            forKey: .playStatus
        )
        clientSequence = (try? container.decode(
            ListenTogetherInteger.self,
            forKey: .clientSequence
        ))?.value ?? 0
        serverSequence = (try? container.decode(
            ListenTogetherInteger.self,
            forKey: .serverSequence
        ))?.value ?? 0
    }

    var targetSongNumericID: Int? {
        targetSongID.flatMap(Int.init)
    }

    var shouldPlay: Bool? {
        switch playStatus?.uppercased() {
        case "PLAY", "PLAYING":
            true
        case "PAUSE", "PAUSED":
            false
        default:
            switch commandType?.uppercased() {
            case "PLAY", "GOTO", "NEXT", "PREV":
                true
            case "PAUSE":
                false
            default:
                nil
            }
        }
    }
}

struct ListenTogetherIdentifier: Decodable, Hashable {
    let rawValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            rawValue = value
        } else if let value = try? container.decode(Int64.self) {
            rawValue = String(value)
        } else if let value = try? container.decode(Double.self) {
            rawValue = String(format: "%.0f", value)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: L10n.string("ui.error.decode.string_or_numeric_id")
                )
            )
        }
    }
}

private struct ListenTogetherInteger: Decodable {
    let value: Int64

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let integer = try? container.decode(Int64.self) {
            value = integer
        } else if let string = try? container.decode(String.self),
                  let integer = Int64(string) {
            value = integer
        } else if let number = try? container.decode(Double.self) {
            value = Int64(number)
        } else {
            throw DecodingError.typeMismatch(
                Int64.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: L10n.string("ui.error.decode.integer")
                )
            )
        }
    }
}

struct ListenTogetherInvitation: Hashable {
    let roomID: String
    let inviterID: String
    let songID: Int?

    init(text: String) throws {
        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else {
            throw ListenTogetherInvitationError.empty
        }

        let normalized = trimmed.replacingOccurrences(
            of: "&amp;",
            with: "&"
        )
        let tokens = normalized.components(
            separatedBy: .whitespacesAndNewlines
        )
        let link = tokens.first(where: {
            $0.localizedCaseInsensitiveContains("roomId=")
        }) ?? normalized
        let components = Self.components(from: link)
        let items = components?.queryItems ?? []

        guard let roomID = Self.queryValue(
            named: "roomId",
            in: items
        ), !roomID.isEmpty else {
            throw ListenTogetherInvitationError.missingRoomID
        }
        guard let inviterID = Self.queryValue(
            named: "inviterId",
            in: items
        ) ?? Self.queryValue(
            named: "inviterUid",
            in: items
        ), !inviterID.isEmpty else {
            throw ListenTogetherInvitationError.missingInviterID
        }

        self.roomID = roomID
        self.inviterID = inviterID
        songID = Self.queryValue(named: "songId", in: items).flatMap(
            Int.init
        )
    }

    private static func components(from source: String) -> URLComponents? {
        if let components = URLComponents(string: source),
           components.queryItems != nil {
            return components
        }

        let query: String
        if let questionMark = source.firstIndex(of: "?") {
            query = String(source[source.index(after: questionMark)...])
        } else {
            query = source
        }
        return URLComponents(
            string: "https://st.music.163.com/listen-together/share/?\(query)"
        )
    }

    private static func queryValue(
        named name: String,
        in items: [URLQueryItem]
    ) -> String? {
        items.first(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        })?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ListenTogetherInvitationError: LocalizedError {
    case empty
    case missingRoomID
    case missingInviterID

    var errorDescription: String? {
        switch self {
        case .empty:
            L10n.string("ui.error.listen_together.invitation_empty")
        case .missingRoomID:
            L10n.string("ui.error.listen_together.missing_room_id")
        case .missingInviterID:
            L10n.string("ui.error.listen_together.missing_inviter_id")
        }
    }
}
