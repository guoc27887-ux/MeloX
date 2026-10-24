import LinkPresentation
import UIKit

enum LyricShareMetadataFactory {
    static func makeMetadata(
        payload: LyricSharePayload,
        artwork: UIImage?
    ) -> LPLinkMetadata {
        let metadata = LPLinkMetadata()
        let firstLine = payload.lyrics.first?.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        metadata.title = if let firstLine, !firstLine.isEmpty {
            L10n.format("ui.lyrics.share.excerpt", firstLine)
        } else {
            L10n.format("ui.lyrics.share.excerpt_song", payload.song.name)
        }
        metadata.url = payload.songURL
        metadata.originalURL = payload.songURL
        if let artwork {
            metadata.imageProvider = NSItemProvider(object: artwork)
        }
        return metadata
    }
}
