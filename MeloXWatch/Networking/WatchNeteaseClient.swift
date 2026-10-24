import CommonCrypto
import CryptoKit
import Foundation
import Security

nonisolated enum WatchNeteaseError: LocalizedError, Sendable {
    case requestEncoding
    case invalidResponse
    case emptyResponse(Int)
    case server(Int, String)
    case loginRequired
    case noPlayableSource

    var errorDescription: String? {
        switch self {
        case .requestEncoding:
            L10n.string("ui.error.api.request_encoding")
        case .invalidResponse:
            L10n.string("ui.error.api.invalid_response")
        case .emptyResponse(let statusCode):
            L10n.format("ui.error.api.empty_response", statusCode)
        case .server(let code, _):
            L10n.format("ui.error.api.server_code", code)
        case .loginRequired:
            L10n.string("ui.error.api.login_required")
        case .noPlayableSource:
            L10n.string("ui.error.api.no_playable_source")
        }
    }
}

struct WatchNeteaseResponse<Value> {
    let value: Value
    let cookies: [HTTPCookie]
}

@MainActor
final class WatchNeteaseClient {
    private let cookieProvider: () -> String
    private let session: URLSession
    private let syntheticDeviceID: String

    init(
        cookieProvider: @escaping () -> String,
        session: URLSession = .shared
    ) {
        self.cookieProvider = cookieProvider
        self.session = session
        syntheticDeviceID = Self.randomHex(byteCount: 26).uppercased()
    }

    func eapi<Response: Decodable>(
        _ uri: String,
        data: [String: Any] = [:],
        authenticated: Bool = false
    ) async throws -> Response {
        try await eapiResponse(
            uri,
            data: data,
            authenticated: authenticated
        ).value
    }

    func eapiData(
        _ uri: String,
        data: [String: Any] = [:],
        authenticated: Bool = false
    ) async throws -> Data {
        try await rawEAPIResponse(
            uri,
            data: data,
            authenticated: authenticated
        ).data
    }

    func eapiResponse<Response: Decodable>(
        _ uri: String,
        data: [String: Any] = [:],
        authenticated: Bool = false
    ) async throws -> WatchNeteaseResponse<Response> {
        let rawResponse = try await rawEAPIResponse(
            uri,
            data: data,
            authenticated: authenticated
        )

        do {
            let value = try JSONDecoder().decode(
                Response.self,
                from: rawResponse.data
            )
            return WatchNeteaseResponse(
                value: value,
                cookies: responseCookies(
                    from: rawResponse.response,
                    url: rawResponse.url
                )
            )
        } catch {
            let payload = try? JSONSerialization.jsonObject(
                with: rawResponse.data
            ) as? [String: Any]
            let code = payload?["code"] as? Int
                ?? rawResponse.response.statusCode
            let message = payload?["message"] as? String
                ?? payload?["msg"] as? String
                ?? error.localizedDescription
            throw WatchNeteaseError.server(code, message)
        }
    }

    private func rawEAPIResponse(
        _ uri: String,
        data: [String: Any],
        authenticated: Bool
    ) async throws -> WatchNeteaseRawResponse {
        var requestData = data
        let header = eapiHeader(authenticated: authenticated)
        requestData["header"] = header
        requestData["e_r"] = false

        let jsonData = try JSONSerialization.data(
            withJSONObject: requestData,
            options: [.sortedKeys]
        )
        guard let json = String(data: jsonData, encoding: .utf8) else {
            throw WatchNeteaseError.requestEncoding
        }
        let message = "nobody\(uri)use\(json)md5forencrypt"
        let digest = Insecure.MD5.hash(data: Data(message.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let payload = "\(uri)-36cd479b6b5-\(json)-36cd479b6b5-\(digest)"
        let params = try encryptAES(
            Data(payload.utf8),
            key: "e82ckenh8dichen8"
        )
        .map { String(format: "%02X", $0) }
        .joined()

        let path = uri.replacingOccurrences(of: "/api/", with: "/eapi/")
        guard let url = URL(string: "https://interface.music.163.com\(path)") else {
            throw WatchNeteaseError.requestEncoding
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue(
            authenticated
                ? "NeteaseMusic 9.0.90/5038 (iPhone; iOS 16.2; zh_CN)"
                : "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(
            encodedCookieHeader(header),
            forHTTPHeaderField: "Cookie"
        )
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "params", value: params)]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (responseData, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WatchNeteaseError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw WatchNeteaseError.server(
                httpResponse.statusCode,
                HTTPURLResponse.localizedString(
                    forStatusCode: httpResponse.statusCode
                )
            )
        }
        guard !responseData.isEmpty else {
            throw WatchNeteaseError.emptyResponse(httpResponse.statusCode)
        }

        return WatchNeteaseRawResponse(
            data: responseData,
            response: httpResponse,
            url: url
        )
    }

    private func responseCookies(
        from response: HTTPURLResponse,
        url: URL
    ) -> [HTTPCookie] {
        var fields: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            guard let key = key as? String else { continue }
            fields[key] = String(describing: value)
        }
        return HTTPCookie.cookies(
            withResponseHeaderFields: fields,
            for: url
        )
    }

    private func eapiHeader(authenticated: Bool) -> [String: String] {
        let cookies = cookieValues
        var header: [String: String] = [
            "osver": cookies["osver"] ?? "16.2",
            "deviceId": cookies["deviceId"] ?? syntheticDeviceID,
            "os": cookies["os"] ?? "iPhone OS",
            "appver": cookies["appver"] ?? "9.0.90",
            "versioncode": cookies["versioncode"] ?? "140",
            "mobilename": cookies["mobilename"] ?? "",
            "buildver": cookies["buildver"]
                ?? String(Int(Date().timeIntervalSince1970)),
            "resolution": cookies["resolution"] ?? "368x448",
            "__csrf": cookies["__csrf"] ?? "",
            "channel": cookies["channel"] ?? "distribution",
            "requestId": "\(Self.timestampMilliseconds)_\(Self.randomDigits(length: 4))"
        ]
        if authenticated, let musicU = cookies["MUSIC_U"] {
            header["MUSIC_U"] = musicU
        }
        return header
    }

    private var cookieValues: [String: String] {
        cookieProvider()
            .split(separator: ";")
            .reduce(into: [:]) { values, pair in
                let parts = pair.split(
                    separator: "=",
                    maxSplits: 1
                ).map(String.init)
                guard parts.count == 2 else { return }
                values[
                    parts[0].trimmingCharacters(in: .whitespaces)
                ] = parts[1].trimmingCharacters(in: .whitespaces)
            }
    }

    private func encodedCookieHeader(_ values: [String: String]) -> String {
        values.keys.sorted().map { key in
            "\(Self.encodeURIComponent(key))=\(Self.encodeURIComponent(values[key] ?? ""))"
        }.joined(separator: "; ")
    }

    private func encryptAES(_ data: Data, key: String) throws -> Data {
        var output = Data(count: data.count + kCCBlockSizeAES128)
        let capacity = output.count
        var outputLength = 0
        let status = output.withUnsafeMutableBytes { outputBytes in
            data.withUnsafeBytes { dataBytes in
                key.withCString { keyBytes in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding)
                            | CCOptions(kCCOptionECBMode),
                        keyBytes,
                        kCCKeySizeAES128,
                        nil,
                        dataBytes.baseAddress,
                        data.count,
                        outputBytes.baseAddress,
                        capacity,
                        &outputLength
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw WatchNeteaseError.requestEncoding
        }
        output.removeSubrange(outputLength..<output.count)
        return output
    }

    private static func randomHex(byteCount: Int) -> String {
        randomString(
            length: byteCount * 2,
            characters: "0123456789abcdef"
        )
    }

    private static func randomDigits(length: Int) -> String {
        randomString(length: length, characters: "0123456789")
    }

    private static func randomString(
        length: Int,
        characters: String
    ) -> String {
        let characters = Array(characters)
        var generator = SystemRandomNumberGenerator()
        return String(
            (0..<length).compactMap { _ in
                characters.randomElement(using: &generator)
            }
        )
    }

    private static func encodeURIComponent(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.!~*'()")
        return value.addingPercentEncoding(
            withAllowedCharacters: allowed
        ) ?? value
    }

    private static var timestampMilliseconds: Int64 {
        Int64(Date().timeIntervalSince1970 * 1_000)
    }
}

private struct WatchNeteaseRawResponse {
    let data: Data
    let response: HTTPURLResponse
    let url: URL
}
