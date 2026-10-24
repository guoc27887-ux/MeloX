import Foundation

struct PersonalFMResponse: Decodable {
    let code: Int
    let data: [Song]
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, data, message, msg
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 200
        data = try container.decodeIfPresent(
            [Song].self,
            forKey: .data
        ) ?? []
        message =
            try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .msg)
    }
}
