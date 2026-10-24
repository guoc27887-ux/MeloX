import Combine
import Foundation

@MainActor
final class WatchPlaybackCoordinator: ObservableObject {
    let standalone: WatchPlaybackStore

    private var cancellables: Set<AnyCancellable> = []

    init(standalone: WatchPlaybackStore) {
        self.standalone = standalone

        standalone.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var song: WatchSong? {
        standalone.currentSong
    }

    var queue: [WatchSong] {
        standalone.queue
    }

    var currentIndex: Int {
        standalone.currentIndex
    }

    var playbackOrderIndices: [Int] {
        standalone.playbackOrderIndices
    }

    var isPlaying: Bool {
        standalone.isPlaying
    }

    var duration: TimeInterval {
        standalone.duration
    }

    var repeatMode: WatchRepeatMode {
        standalone.repeatMode
    }

    var isShuffled: Bool {
        standalone.isShuffled
    }

    var volume: Double {
        standalone.volume
    }

    var isLoading: Bool {
        standalone.isLoading
    }

    var errorMessage: String? {
        standalone.errorMessage
    }

    var effectiveStreamingQuality: WatchStreamingQuality? {
        standalone.effectiveStreamingQuality
    }

    func position(at date: Date = Date()) -> TimeInterval {
        standalone.position(at: date)
    }

    func play(_ song: WatchSong, in songs: [WatchSong]? = nil) async {
        await standalone.play(song, in: songs)
    }

    func togglePlayback() {
        standalone.togglePlayback()
    }

    func previous() async {
        await standalone.previous()
    }

    func next() async {
        await standalone.next()
    }

    func seek(to position: TimeInterval) {
        standalone.seek(to: position)
    }

    func playQueueItem(at index: Int) async {
        await standalone.playQueueItem(at: index)
    }

    func cycleRepeatMode() {
        standalone.cycleRepeatMode()
    }

    func setRepeatMode(_ mode: WatchRepeatMode) {
        standalone.setRepeatMode(mode)
    }

    func toggleShuffle() {
        standalone.toggleShuffle()
    }

    func setShuffleEnabled(_ isEnabled: Bool) {
        standalone.setShuffleEnabled(isEnabled)
    }

    func setPlaybackMode(
        isShuffled: Bool,
        repeatMode: WatchRepeatMode
    ) {
        standalone.setPlaybackMode(
            isShuffled: isShuffled,
            repeatMode: repeatMode
        )
    }

    func setVolume(_ value: Double) {
        standalone.setVolume(value)
    }

    func reloadForSelectedQuality() async {
        await standalone.reloadForSelectedQuality()
    }

    func setRestoresLastSession(_ isEnabled: Bool) {
        standalone.setRestoresLastSession(isEnabled)
    }
}
