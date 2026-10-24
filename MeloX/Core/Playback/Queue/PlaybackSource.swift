import Foundation

struct PlaybackSource: Equatable, Sendable {
    let url: URL
    let bitrate: Int?
    let format: String?
    let quality: MusicQuality?
    /// 网易云返回的地址是否仅为试听片段（freeTrialInfo 非空）。灰色解锁
    /// 靠它判断“仅试听”曲目；默认 false，保持其它构造点行为不变。
    let isTrial: Bool

    init(
        url: URL,
        bitrate: Int?,
        format: String?,
        quality: MusicQuality? = nil,
        isTrial: Bool = false
    ) {
        self.url = url
        self.bitrate = bitrate
        self.format = format
        self.quality = quality
        self.isTrial = isTrial
    }

    var preferredForwardBufferDuration: TimeInterval {
        guard !url.isFileURL else { return 0 }
        if quality?.prefersExtendedBuffering == true
            || (bitrate ?? 0) >= 1_000_000 {
            return 16
        }
        return 8
    }
}
