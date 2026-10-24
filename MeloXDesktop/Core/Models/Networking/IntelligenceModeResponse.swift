import Foundation

struct IntelligenceModeResponse: Decodable {
    let code: Int
    let data: [IntelligenceModeItem]
    let message: String?
}

struct IntelligenceModeItem: Decodable {
    let id: Int
}
