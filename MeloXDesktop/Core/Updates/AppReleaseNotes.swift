import Foundation

struct AppReleaseNotes: Equatable, Identifiable, Sendable {
    let version: String
    let sourceRevision: String
    let previousVersion: String?
    let localizedEntries: [String: [String]]

    var id: String {
        "\(version)-\(sourceRevision)"
    }

    var displayVersion: String {
        AppVersion.displayName(for: version)
    }

    var displayPreviousVersion: String? {
        guard let previousVersion else { return nil }
        return AppVersion.displayName(for: previousVersion)
    }

    var entries: [String] {
        let languageCode = L10n.locale.language.languageCode?.identifier
        let localeKey = languageCode == "zh" ? "zh-Hans" : "en"
        return localizedEntries[localeKey]
            ?? localizedEntries["en"]
            ?? localizedEntries["zh-Hans"]
            ?? []
    }
}

enum AppReleaseNotesLoader {
    static func load(from bundle: Bundle = .main) -> AppReleaseNotes? {
        guard let metadataURL = bundle.url(
            forResource: "ReleaseNotes",
            withExtension: "json"
        ),
        let metadataData = try? Data(contentsOf: metadataURL),
        let metadata = try? JSONDecoder().decode(
            AppReleaseNotesMetadata.self,
            from: metadataData
        ),
        metadata.schemaVersion == 3,
        metadata.localizedEntries["zh-Hans"]?.isEmpty == false,
        metadata.localizedEntries["en"]?.isEmpty == false,
        metadata.localizedEntries["zh-Hans"]?.count
            == metadata.localizedEntries["en"]?.count,
        !metadata.version.isEmpty else {
            return nil
        }

        return AppReleaseNotes(
            version: metadata.version,
            sourceRevision: metadata.sourceRevision,
            previousVersion: metadata.previousVersion,
            localizedEntries: metadata.localizedEntries
        )
    }
}

private struct AppReleaseNotesMetadata: Decodable {
    let schemaVersion: Int
    let version: String
    let sourceRevision: String
    let previousVersion: String?
    let localizedEntries: [String: [String]]
}
