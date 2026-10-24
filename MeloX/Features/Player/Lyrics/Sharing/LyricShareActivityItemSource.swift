import LinkPresentation
import UIKit

final class LyricShareTextActivityItemSource: NSObject,
    UIActivityItemSource
{
    private let payload: LyricSharePayload

    init(payload: LyricSharePayload) {
        self.payload = payload
        super.init()
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        payload.originalLyricsText as NSString
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        payload.originalLyricsText as NSString
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        payload.subject
    }
}

final class LyricShareURLActivityItemSource: NSObject,
    UIActivityItemSource
{
    private let payload: LyricSharePayload
    private let artwork: UIImage?

    init(
        payload: LyricSharePayload,
        artwork: UIImage?
    ) {
        self.payload = payload
        self.artwork = artwork
        super.init()
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        payload.songURL as NSURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        if activityType == .message,
           let messageURL = payload.messagesLyricsURL {
            return messageURL as NSURL
        }
        return payload.songURL as NSURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        payload.subject
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        return LyricShareMetadataFactory.makeMetadata(
            payload: payload,
            artwork: artwork
        )
    }
}

private extension LyricSharePayload {
    var messagesLyricsURL: URL? {
        guard var components = URLComponents(
            url: songURL,
            resolvingAgainstBaseURL: false
        ), components.scheme?.lowercased() == "https",
        let host = components.host?.lowercased(),
        host == "music.163.com"
            || host.hasSuffix(".music.163.com") else {
            return nil
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll {
            $0.name == "itscg" || $0.name == "itsct"
        }
        queryItems.append(contentsOf: [
            URLQueryItem(name: "itscg", value: "50401"),
            URLQueryItem(
                name: "itsct",
                value: "sharing_msg_lyrics"
            ),
        ])
        components.queryItems = queryItems
        return components.url
    }
}
