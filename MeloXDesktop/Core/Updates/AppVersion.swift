import Foundation

enum AppVersion {
    private static let buildPrefix = 91
    private static let buildPrefixScale = 100_000
    private static let patchComponentScale = 100

    static func compare(_ lhs: String, to rhs: String) -> ComparisonResult {
        let lhsParts = normalizedParts(lhs)
        let rhsParts = normalizedParts(rhs)
        let count = max(lhsParts.count, rhsParts.count)

        for index in 0..<count {
            let lhsValue = index < lhsParts.count ? lhsParts[index] : 0
            let rhsValue = index < rhsParts.count ? rhsParts[index] : 0

            if lhsValue < rhsValue { return .orderedAscending }
            if lhsValue > rhsValue { return .orderedDescending }
        }

        return .orderedSame
    }

    static func isEquivalent(_ lhs: String, to rhs: String) -> Bool {
        compare(lhs, to: rhs) == .orderedSame
    }

    static func displayName(for version: String) -> String {
        var trimmedVersion = version.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if trimmedVersion.lowercased().hasSuffix("_mac") {
            trimmedVersion.removeLast(4)
        }
        if trimmedVersion.lowercased().hasPrefix("v") {
            trimmedVersion.removeFirst()
        }
        return trimmedVersion
    }

    static func releaseVersion(fromBuildNumber buildNumber: String) -> String? {
        let trimmedBuildNumber = buildNumber.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard let encodedVersion = Int(trimmedBuildNumber),
              encodedVersion / buildPrefixScale == buildPrefix else {
            return nil
        }

        let versionDigits = encodedVersion % buildPrefixScale
        let majorScale = 10_000
        let major = versionDigits / majorScale
        let remainder = versionDigits % majorScale
        let minor = remainder / patchComponentScale
        let patch = remainder % patchComponentScale
        return "\(major).\(minor).\(patch)"
    }

    private static func normalizedParts(_ version: String) -> [Int] {
        version
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            .split { !$0.isNumber }
            .compactMap { Int($0) }
    }
}

extension Bundle {
    var appVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.1"
    }

    var appBuildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    /// Build numbers use a fixed `91` prefix, one digit for major, and two
    /// digits each for minor/patch. macOS versions advance independently.
    var appReleaseVersion: String {
        AppVersion.releaseVersion(fromBuildNumber: appBuildNumber)
            ?? appBuildNumber
    }
}
