import Foundation

/// QQ Music QRC uses a legacy DES implementation whose S-box contains two
/// values that differ from standardized DES. They must remain unchanged for
/// compatibility with the encrypted lyric payload.
nonisolated enum QQMusicModifiedDES {
    static func decrypt(_ data: Data) -> Data? {
        guard data.count.isMultiple(of: 8) else { return nil }
        let source = [UInt8](data)
        let keys = [
            Array("!@#)(NHL".utf8),
            Array("123ZXC!@".utf8),
            Array("!@#)(*$%".utf8),
        ]
        var result: [UInt8] = []
        result.reserveCapacity(source.count)

        for offset in stride(from: 0, to: source.count, by: 8) {
            var block = Array(source[offset..<(offset + 8)])
            block = crypt(block, key: keys[0], decrypts: true)
            block = crypt(block, key: keys[1], decrypts: false)
            block = crypt(block, key: keys[2], decrypts: true)
            result.append(contentsOf: block)
        }
        return Data(result)
    }

    private static func crypt(
        _ block: [UInt8],
        key: [UInt8],
        decrypts: Bool
    ) -> [UInt8] {
        let input = uint64(wordReversed(block))
        let keyValue = uint64(wordReversed(key))
        var roundKeys = makeRoundKeys(keyValue)
        if decrypts { roundKeys.reverse() }
        let initial = permute(input, inputWidth: 64, table: initialPermutation)
        var left = UInt32(truncatingIfNeeded: initial >> 32)
        var right = UInt32(truncatingIfNeeded: initial)
        for roundKey in roundKeys {
            let previousRight = right
            right = left ^ function(right, roundKey: roundKey)
            left = previousRight
        }
        let swapped = (UInt64(right) << 32) | UInt64(left)
        let output = permute(swapped, inputWidth: 64, table: finalPermutation)
        return wordReversed(bytes(output))
    }

    private static func makeRoundKeys(_ key: UInt64) -> [UInt64] {
        let selected = permute(key, inputWidth: 64, table: keyPermutation)
        var left = UInt32((selected >> 28) & 0x0FFF_FFFF)
        var right = UInt32(selected & 0x0FFF_FFFF)
        return rotations.map { rotation in
            left = rotate28(left, by: rotation)
            right = rotate28(right, by: rotation)
            return compressedKey(left: left, right: right)
        }
    }

    private static func compressedKey(left: UInt32, right: UInt32) -> UInt64 {
        keyCompression.enumerated().reduce(into: UInt64(0)) { result, entry in
            result <<= 1
            if entry.offset < 24 {
                result |= UInt64((left >> UInt32(28 - entry.element)) & 1)
            } else {
                // The QQ client historically subtracts 27 instead of 28
                // when indexing the D half of PC-2. Preserve that quirk.
                let position = entry.element - 27
                if position <= 28 {
                    result |= UInt64((right >> UInt32(28 - position)) & 1)
                }
            }
        }
    }

    private static func function(_ value: UInt32, roundKey: UInt64) -> UInt32 {
        let expanded = permute(UInt64(value), inputWidth: 32, table: expansion) ^ roundKey
        var substituted: UInt32 = 0
        for boxIndex in 0..<8 {
            let value = Int((expanded >> UInt64(42 - boxIndex * 6)) & 0x3F)
            let row = ((value & 0x20) >> 4) | (value & 1)
            let column = (value >> 1) & 0x0F
            substituted = (substituted << 4) | UInt32(sBoxes[boxIndex][row * 16 + column])
        }
        return UInt32(truncatingIfNeeded: permute(UInt64(substituted), inputWidth: 32, table: functionPermutation))
    }

    private static func permute(_ value: UInt64, inputWidth: Int, table: [Int]) -> UInt64 {
        table.reduce(into: UInt64(0)) { result, position in
            result = (result << 1) | ((value >> UInt64(inputWidth - position)) & 1)
        }
    }

    private static func rotate28(_ value: UInt32, by amount: Int) -> UInt32 {
        ((value << amount) | (value >> (28 - amount))) & 0x0FFF_FFFF
    }

    private static func wordReversed(_ bytes: [UInt8]) -> [UInt8] {
        var result: [UInt8] = []
        result.reserveCapacity(bytes.count)
        for offset in stride(from: 0, to: bytes.count, by: 4) {
            result.append(contentsOf: bytes[offset..<min(offset + 4, bytes.count)].reversed())
        }
        return result
    }

    private static func uint64(_ bytes: [UInt8]) -> UInt64 {
        bytes.reduce(into: UInt64(0)) { $0 = ($0 << 8) | UInt64($1) }
    }

    private static func bytes(_ value: UInt64) -> [UInt8] {
        (0..<8).map { UInt8(truncatingIfNeeded: value >> UInt64((7 - $0) * 8)) }
    }

    private static let rotations = [1,1,2,2,2,2,2,2,1,2,2,2,2,2,2,1]
    private static let initialPermutation = [58,50,42,34,26,18,10,2,60,52,44,36,28,20,12,4,62,54,46,38,30,22,14,6,64,56,48,40,32,24,16,8,57,49,41,33,25,17,9,1,59,51,43,35,27,19,11,3,61,53,45,37,29,21,13,5,63,55,47,39,31,23,15,7]
    private static let finalPermutation = [40,8,48,16,56,24,64,32,39,7,47,15,55,23,63,31,38,6,46,14,54,22,62,30,37,5,45,13,53,21,61,29,36,4,44,12,52,20,60,28,35,3,43,11,51,19,59,27,34,2,42,10,50,18,58,26,33,1,41,9,49,17,57,25]
    private static let keyPermutation = [57,49,41,33,25,17,9,1,58,50,42,34,26,18,10,2,59,51,43,35,27,19,11,3,60,52,44,36,63,55,47,39,31,23,15,7,62,54,46,38,30,22,14,6,61,53,45,37,29,21,13,5,28,20,12,4]
    private static let keyCompression = [14,17,11,24,1,5,3,28,15,6,21,10,23,19,12,4,26,8,16,7,27,20,13,2,41,52,31,37,47,55,30,40,51,45,33,48,44,49,39,56,34,53,46,42,50,36,29,32]
    private static let expansion = [32,1,2,3,4,5,4,5,6,7,8,9,8,9,10,11,12,13,12,13,14,15,16,17,16,17,18,19,20,21,20,21,22,23,24,25,24,25,26,27,28,29,28,29,30,31,32,1]
    private static let functionPermutation = [16,7,20,21,29,12,28,17,1,15,23,26,5,18,31,10,2,8,24,14,32,27,3,9,19,13,30,6,22,11,4,25]
    private static let sBoxes = [
        [14,4,13,1,2,15,11,8,3,10,6,12,5,9,0,7,0,15,7,4,14,2,13,1,10,6,12,11,9,5,3,8,4,1,14,8,13,6,2,11,15,12,9,7,3,10,5,0,15,12,8,2,4,9,1,7,5,11,3,14,10,0,6,13],
        [15,1,8,14,6,11,3,4,9,7,2,13,12,0,5,10,3,13,4,7,15,2,8,15,12,0,1,10,6,9,11,5,0,14,7,11,10,4,13,1,5,8,12,6,9,3,2,15,13,8,10,1,3,15,4,2,11,6,7,12,0,5,14,9],
        [10,0,9,14,6,3,15,5,1,13,12,7,11,4,2,8,13,7,0,9,3,4,6,10,2,8,5,14,12,11,15,1,13,6,4,9,8,15,3,0,11,1,2,12,5,10,14,7,1,10,13,0,6,9,8,7,4,15,14,3,11,5,2,12],
        [7,13,14,3,0,6,9,10,1,2,8,5,11,12,4,15,13,8,11,5,6,15,0,3,4,7,2,12,1,10,14,9,10,6,9,0,12,11,7,13,15,1,3,14,5,2,8,4,3,15,0,6,10,10,13,8,9,4,5,11,12,7,2,14],
        [2,12,4,1,7,10,11,6,8,5,3,15,13,0,14,9,14,11,2,12,4,7,13,1,5,0,15,10,3,9,8,6,4,2,1,11,10,13,7,8,15,9,12,5,6,3,0,14,11,8,12,7,1,14,2,13,6,15,0,9,10,4,5,3],
        [12,1,10,15,9,2,6,8,0,13,3,4,14,7,5,11,10,15,4,2,7,12,9,5,6,1,13,14,0,11,3,8,9,14,15,5,2,8,12,3,7,0,4,10,1,13,11,6,4,3,2,12,9,5,15,10,11,14,1,7,6,0,8,13],
        [4,11,2,14,15,0,8,13,3,12,9,7,5,10,6,1,13,0,11,7,4,9,1,10,14,3,5,12,2,15,8,6,1,4,11,13,12,3,7,14,10,15,6,8,0,5,9,2,6,11,13,8,1,4,10,7,9,5,0,15,14,2,3,12],
        [13,2,8,4,6,15,11,1,10,9,3,14,5,0,12,7,1,15,13,8,10,3,7,4,12,5,6,11,0,14,9,2,7,11,4,1,9,12,14,2,0,6,10,13,15,3,5,8,2,1,14,7,4,10,8,13,15,12,9,0,3,5,6,11],
    ]
}
