import Foundation

struct AudioMatchResponse: Decodable {
    let code: Int
    let data: AudioMatchData?
}

struct AudioMatchData: Decodable {
    let result: [AudioMatchCandidate]?
}

struct AudioMatchCandidate: Decodable {
    let song: Song
    let startTime: Int?
}
