import Foundation

extension NeteaseAPI {
    func userPlayRecords(
        userID: Int,
        period: UserPlayRecordPeriod
    ) async throws -> [UserPlayRecord] {
        let path = "/api/v1/play/record"
        let data: [String: Any] = [
            "uid": userID,
            "type": period.rawValue,
        ]
        let response: UserPlayRecordsResponse

        do {
            // Mirrors @neteaseapireborn/api/module/user_record.js.
            response = try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            // Keep the original route and parameters when CFNetwork receives
            // an empty weapi response, changing only the transport.
            response = try await client.eapi(
                path,
                data: data,
                authenticated: true
            )
        }

        try validate(
            responseCode: response.code,
            message: response.message
        )
        return response.records(for: period).filter { $0.song.id > 0 }
    }
}
