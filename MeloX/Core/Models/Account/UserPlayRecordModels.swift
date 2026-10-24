import Foundation

enum UserPlayRecordPeriod: Int, CaseIterable, Identifiable {
    case week = 1
    case allTime = 0

    var id: Int { rawValue }
}

struct UserPlayRecord: Decodable, Hashable {
    let song: Song
    let playCount: Int
    let score: Int?
}

struct UserPlayRecordsResponse: Decodable {
    let code: Int
    let weekData: [UserPlayRecord]
    let allData: [UserPlayRecord]
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, weekData, allData, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 200
        weekData = try container.decodeIfPresent(
            [UserPlayRecord].self,
            forKey: .weekData
        ) ?? []
        allData = try container.decodeIfPresent(
            [UserPlayRecord].self,
            forKey: .allData
        ) ?? []
        message = try container.decodeIfPresent(
            String.self,
            forKey: .message
        )
    }

    func records(for period: UserPlayRecordPeriod) -> [UserPlayRecord] {
        switch period {
        case .week:
            weekData
        case .allTime:
            allData
        }
    }
}
