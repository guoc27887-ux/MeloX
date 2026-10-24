import Foundation

struct AppUpdateResult: Equatable, Sendable {
    let currentVersion: String
    let latestVersion: String
    let releaseName: String
    let releaseURL: URL
    let publishedAt: Date?

    var hasUpdate: Bool {
        AppVersion.compare(latestVersion, to: currentVersion)
            == .orderedDescending
    }
}

enum AppUpdateService {
    nonisolated static let repositoryURL = URL(string: "https://github.com/youshen2/MeloX")!
    private nonisolated static let releasesURL = URL(
        string: "https://api.github.com/repos/youshen2/MeloX/releases?per_page=100"
    )!

    nonisolated static func checkLatestRelease(currentVersion: String) async throws -> AppUpdateResult {
        var request = URLRequest(
            url: releasesURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 20
        )
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("MeloX", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode != 404 else {
            throw AppUpdateError.noRelease
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let releases = try decoder.decode([GitHubRelease].self, from: data)
        guard let release = releases.first(where: { release in
            !release.isDraft
                && !release.isPrerelease
                && !release.tagName.lowercased().hasSuffix("_mac")
        }) else {
            throw AppUpdateError.noRelease
        }
        let latestVersion = release.tagName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !latestVersion.isEmpty,
              let releaseURL = URL(string: release.htmlURL) else {
            throw AppUpdateError.invalidRelease
        }
        let releaseName = (release.name?.isEmpty == false ? release.name : nil) ?? latestVersion

        return AppUpdateResult(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseName: releaseName,
            releaseURL: releaseURL,
            publishedAt: release.publishedAt
        )
    }
}

enum AppUpdateError: LocalizedError {
    case noRelease
    case invalidRelease

    var errorDescription: String? {
        switch self {
        case .noRelease:
            L10n.string("ui.error.update.no_release")
        case .invalidRelease:
            L10n.string("ui.error.update.invalid_release")
        }
    }
}

private nonisolated struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let htmlURL: String
    let publishedAt: Date?
    let isDraft: Bool
    let isPrerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case isDraft = "draft"
        case isPrerelease = "prerelease"
    }
}
