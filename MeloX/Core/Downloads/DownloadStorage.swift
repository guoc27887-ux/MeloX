import Foundation

final class DownloadStorage {
    private let fileManager: FileManager
    private let directoryURL: URL

    init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL
            ?? AppStorageLocations.downloadsDirectory(
                fileManager: fileManager
            )
    }

    func installDownloadedFile(
        from temporaryURL: URL,
        songID: Int,
        format: String?,
        sourceURL: URL
    ) throws -> (fileName: String, byteCount: Int64) {
        try prepareDirectory()
        let fileName = "\(songID).\(fileExtension(format: format, sourceURL: sourceURL))"
        let destinationURL = fileURL(fileName: fileName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)

        let values = try destinationURL.resourceValues(forKeys: [.fileSizeKey])
        let byteCount = Int64(values.fileSize ?? 0)
        guard byteCount > 0 else {
            try? fileManager.removeItem(at: destinationURL)
            throw DownloadError.emptyFile
        }
        return (fileName, byteCount)
    }

    func removeFile(named fileName: String) throws {
        let url = fileURL(fileName: fileName)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func removeAllFiles() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.removeItem(at: directoryURL)
    }

    @discardableResult
    func removeUntrackedFiles(
        keeping fileNames: Set<String>
    ) throws -> Int64 {
        guard fileManager.fileExists(
            atPath: directoryURL.path
        ) else {
            return 0
        }
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [
                .fileSizeKey,
                .totalFileAllocatedSizeKey,
            ],
            options: [.skipsHiddenFiles]
        )
        var removedByteCount = Int64(0)
        for url in contents
        where !fileNames.contains(url.lastPathComponent) {
            let values = try? url.resourceValues(
                forKeys: [
                    .fileSizeKey,
                    .totalFileAllocatedSizeKey,
                ]
            )
            removedByteCount += Int64(
                values?.totalFileAllocatedSize
                    ?? values?.fileSize
                    ?? 0
            )
            try fileManager.removeItem(at: url)
        }
        return removedByteCount
    }

    func containsFile(named fileName: String) -> Bool {
        fileManager.fileExists(atPath: fileURL(fileName: fileName).path)
    }

    func fileURL(fileName: String) -> URL {
        directoryURL.appending(path: fileName, directoryHint: .notDirectory)
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableDirectoryURL = directoryURL
        try? mutableDirectoryURL.setResourceValues(resourceValues)
    }

    private func fileExtension(format: String?, sourceURL: URL) -> String {
        let proposed = format?.lowercased() ?? sourceURL.pathExtension.lowercased()
        let allowed = CharacterSet.alphanumerics
        let normalized = proposed.unicodeScalars.filter(allowed.contains).map(String.init).joined()
        return normalized.isEmpty ? "audio" : String(normalized.prefix(10))
    }
}

enum DownloadError: LocalizedError {
    case invalidResponse
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            L10n.string("ui.error.download.invalid_response")
        case .emptyFile:
            L10n.string("ui.error.download.empty_file")
        }
    }
}
