import Foundation
import zlib

nonisolated enum QQMusicLyricDecoder {
    static func decode(_ encryptedHex: String) -> String? {
        guard !encryptedHex.isEmpty,
              let encrypted = data(fromHex: encryptedHex),
              let decrypted = QQMusicModifiedDES.decrypt(encrypted),
              let inflated = decompressZlib(decrypted),
              let source = String(data: inflated, encoding: .utf8) else {
            return nil
        }

        if let content = lyricContent(in: source, type: "1")
            ?? lyricContent(in: source, type: "0") {
            return decodeXMLEntities(content)
        }
        return source.first == "[" ? source : nil
    }

    private static func decompressZlib(_ data: Data) -> Data? {
        var stream = z_stream()
        let initialization = zlib.inflateInit_(
            &stream,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initialization == Z_OK else { return nil }
        defer { zlib.inflateEnd(&stream) }

        return data.withUnsafeBytes { inputBytes in
            stream.next_in = UnsafeMutablePointer<Bytef>(
                mutating: inputBytes.bindMemory(to: Bytef.self).baseAddress
            )
            stream.avail_in = uInt(data.count)
            var result = Data()
            let bufferSize = 64 * 1_024
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            var status: Int32 = Z_OK

            repeat {
                let written = buffer.withUnsafeMutableBytes { outputBytes in
                    stream.next_out = outputBytes
                        .bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(bufferSize)
                    status = zlib.inflate(&stream, Z_NO_FLUSH)
                    return bufferSize - Int(stream.avail_out)
                }
                result.append(contentsOf: buffer.prefix(written))
            } while status == Z_OK

            return status == Z_STREAM_END ? result : nil
        }
    }

    private static func data(fromHex value: String) -> Data? {
        guard value.count.isMultiple(of: 2) else { return nil }
        var result = Data(capacity: value.count / 2)
        var index = value.startIndex
        while index < value.endIndex {
            let next = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index..<next], radix: 16) else {
                return nil
            }
            result.append(byte)
            index = next
        }
        return result
    }

    private static func lyricContent(
        in source: String,
        type: String
    ) -> String? {
        let pattern = #"<Lyric_1\s+LyricType=\""#
            + NSRegularExpression.escapedPattern(for: type)
            + #"\"\s+LyricContent=\"(.*?)\"\s*/>"#
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ),
        let match = expression.firstMatch(
            in: source,
            range: NSRange(source.startIndex..., in: source)
        ),
        let range = Range(match.range(at: 1), in: source) else {
            return nil
        }
        return String(source[range])
    }

    private static func decodeXMLEntities(_ source: String) -> String {
        source
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
