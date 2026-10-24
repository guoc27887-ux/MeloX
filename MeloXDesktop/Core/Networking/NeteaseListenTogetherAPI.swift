import Foundation

enum ListenTogetherCommandType: String {
    case play = "PLAY"
    case pause = "PAUSE"
    case next = "NEXT"
    case previous = "PREV"
    case goTo = "GOTO"
    case progress = "PROGRESS"
}

extension NeteaseAPI {
    func createListenTogetherRoom() async throws -> ListenTogetherRoomPayload {
        let response: ListenTogetherRoomResponse = try await client.eapi(
            "/api/listen/together/room/create",
            data: ["refer": "songplay_more"],
            authenticated: true
        )
        try validate(
            responseCode: response.code,
            message: response.message
        )
        guard let data = response.data,
              let room = data.roomInfo,
              !room.id.isEmpty else {
            throw APIError.invalidResponse
        }
        return data
    }

    func listenTogetherRoomStatus() async throws
        -> ListenTogetherRoomStatus {
        let path = "/api/listen/together/status/get"
        let response: ListenTogetherRoomStatusResponse
        do {
            // @neteaseapireborn/api/module/listentogether_status.js
            // explicitly selects weapi for this route.
            response = try await client.weapi(path)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            // Keep the original route and payload when CFNetwork receives
            // an empty weapi body, matching the other authenticated fallbacks.
            response = try await client.eapi(
                path,
                authenticated: true
            )
        }
        try validate(
            responseCode: response.code,
            message: response.message
        )
        guard let data = response.data else {
            throw APIError.invalidResponse
        }
        return data
    }

    func checkListenTogetherRoom(
        roomID: String
    ) async throws -> ListenTogetherRoomCheck {
        let response: ListenTogetherRoomCheckResponse = try await client.eapi(
            "/api/listen/together/room/check",
            data: ["roomId": roomID],
            authenticated: true
        )
        try validate(
            responseCode: response.code,
            message: response.message
        )
        guard let data = response.data else {
            throw APIError.invalidResponse
        }
        return data
    }

    func acceptListenTogetherInvitation(
        roomID: String,
        inviterID: String
    ) async throws -> ListenTogetherRoomPayload {
        let response: ListenTogetherRoomResponse = try await client.eapi(
            "/api/listen/together/play/invitation/accept",
            data: [
                "refer": "inbox_invite",
                "roomId": roomID,
                "inviterId": inviterID,
            ],
            authenticated: true
        )
        try validate(
            responseCode: response.code,
            message: response.message
        )
        guard let data = response.data else {
            throw APIError.invalidResponse
        }
        return data
    }

    func listenTogetherPlayback(
        roomID: String
    ) async throws -> ListenTogetherPlaybackPayload {
        let response: ListenTogetherPlaybackResponse = try await client.eapi(
            "/api/listen/together/sync/playlist/get",
            data: ["roomId": roomID],
            authenticated: true
        )
        try validate(
            responseCode: response.code,
            message: response.message
        )
        guard let data = response.data else {
            throw APIError.invalidResponse
        }
        return data
    }

    func reportListenTogetherPlaylist(
        roomID: String,
        userID: Int,
        version: Int,
        displaySongIDs: [Int],
        randomSongIDs: [Int],
        commandType: String = "REPLACE"
    ) async throws {
        let playlist = try listenTogetherJSONString([
            "commandType": commandType,
            "version": [
                [
                    "userId": userID,
                    "version": version,
                ],
            ],
            "anchorSongId": "",
            "anchorPosition": -1,
            "randomList": randomSongIDs.map(String.init),
            "displayList": displaySongIDs.map(String.init),
        ])
        let response: ListenTogetherActionResponse = try await client.eapi(
            "/api/listen/together/sync/list/command/report",
            data: [
                "roomId": roomID,
                "playlistParam": playlist,
            ],
            authenticated: true
        )
        try validateListenTogetherAction(response)
    }

    func reportListenTogetherCommand(
        roomID: String,
        commandType: ListenTogetherCommandType,
        progressMilliseconds: Int64,
        isPlaying: Bool,
        formerSongID: Int?,
        targetSongID: Int,
        clientSequence: Int
    ) async throws {
        let command = try listenTogetherJSONString([
            "commandType": commandType.rawValue,
            "progress": max(progressMilliseconds, 0),
            "playStatus": isPlaying ? "PLAY" : "PAUSE",
            "formerSongId": String(formerSongID ?? -1),
            "targetSongId": String(targetSongID),
            "clientSeq": clientSequence,
        ])
        let response: ListenTogetherActionResponse = try await client.eapi(
            "/api/listen/together/play/command/report",
            data: [
                "roomId": roomID,
                "commandInfo": command,
            ],
            authenticated: true
        )
        try validateListenTogetherAction(response)
    }

    @discardableResult
    func sendListenTogetherHeartbeat(
        roomID: String,
        songID: Int,
        isPlaying: Bool,
        progressMilliseconds: Int64
    ) async throws -> Int? {
        let response: ListenTogetherActionResponse = try await client.eapi(
            "/api/listen/together/heartbeat",
            data: [
                "roomId": roomID,
                "songId": songID,
                "playStatus": isPlaying ? "PLAY" : "PAUSE",
                "progress": max(progressMilliseconds, 0),
            ],
            authenticated: true
        )
        try validateListenTogetherAction(response)
        return response.data?.timeSpan
    }

    func endListenTogetherRoom(roomID: String) async throws {
        let response: ListenTogetherActionResponse = try await client.eapi(
            "/api/listen/together/end/v2",
            data: ["roomId": roomID],
            authenticated: true
        )
        try validate(
            responseCode: response.code,
            message: response.message
        )
        if response.data?.success == false
            || response.data?.result == false {
            throw APIError.server(
                statusCode: response.code,
                message: response.message ?? L10n.string("ui.error.listen_together.end_failed")
            )
        }
    }

    private func validateListenTogetherAction(
        _ response: ListenTogetherActionResponse
    ) throws {
        try validate(
            responseCode: response.code,
            message: response.message
        )
        if response.data?.result == false
            || response.data?.success == false {
            throw APIError.server(
                statusCode: response.code,
                message: response.message ?? L10n.string("ui.error.listen_together.operation_incomplete")
            )
        }
    }

    private func listenTogetherJSONString(
        _ object: [String: Any]
    ) throws -> String {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw APIError.requestEncoding
        }
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        guard let string = String(data: data, encoding: .utf8) else {
            throw APIError.requestEncoding
        }
        return string
    }
}
