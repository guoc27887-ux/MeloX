import Foundation

struct WatchPlaybackQueue {
    private(set) var songs: [WatchSong] = []
    private(set) var currentIndex = 0
    private(set) var isShuffled = false

    private(set) var shuffledOrder: [Int] = []
    private var shuffledPosition = 0

    var currentSong: WatchSong? {
        guard songs.indices.contains(currentIndex) else { return nil }
        return songs[currentIndex]
    }

    var playbackOrderIndices: [Int] {
        guard isShuffled, isValidShuffleOrder(shuffledOrder) else {
            return Array(songs.indices)
        }
        return shuffledOrder
    }

    mutating func replace(
        with songs: [WatchSong],
        startingAt index: Int
    ) {
        self.songs = songs
        currentIndex = songs.isEmpty
            ? 0
            : min(max(index, 0), songs.count - 1)
        if isShuffled {
            rebuildShuffleOrder()
        }
    }

    @discardableResult
    mutating func select(index: Int) -> Bool {
        guard songs.indices.contains(index) else { return false }
        currentIndex = index
        alignShufflePosition()
        return true
    }

    @discardableResult
    mutating func move(by offset: Int, wraps: Bool) -> Bool {
        let order = playbackOrderIndices
        guard !order.isEmpty else { return false }

        let position = isShuffled
            ? shuffledPosition
            : currentIndex
        var destination = position + offset
        if !order.indices.contains(destination) {
            guard wraps else { return false }
            destination = offset > 0 ? 0 : order.count - 1
        }

        if isShuffled {
            shuffledPosition = destination
            currentIndex = order[destination]
        } else {
            currentIndex = destination
        }
        return true
    }

    mutating func setShuffleEnabled(_ isEnabled: Bool) {
        guard isShuffled != isEnabled else { return }
        isShuffled = isEnabled
        if isEnabled {
            rebuildShuffleOrder()
        } else {
            shuffledOrder = []
            shuffledPosition = 0
        }
    }

    mutating func restore(
        songs: [WatchSong],
        currentIndex: Int,
        isShuffled: Bool,
        shuffledOrder: [Int]
    ) {
        self.songs = songs
        self.currentIndex = songs.isEmpty
            ? 0
            : min(max(currentIndex, 0), songs.count - 1)
        self.isShuffled = isShuffled

        if isShuffled, isValidShuffleOrder(shuffledOrder) {
            self.shuffledOrder = shuffledOrder
            shuffledPosition =
                shuffledOrder.firstIndex(of: self.currentIndex) ?? 0
        } else if isShuffled {
            rebuildShuffleOrder()
        } else {
            self.shuffledOrder = []
            shuffledPosition = 0
        }
    }

    private mutating func rebuildShuffleOrder() {
        guard songs.indices.contains(currentIndex) else {
            shuffledOrder = []
            shuffledPosition = 0
            return
        }
        shuffledOrder = [currentIndex]
            + songs.indices
            .filter { $0 != currentIndex }
            .shuffled()
        shuffledPosition = 0
    }

    private mutating func alignShufflePosition() {
        guard isShuffled else { return }
        if let position = shuffledOrder.firstIndex(of: currentIndex) {
            shuffledPosition = position
        } else {
            rebuildShuffleOrder()
        }
    }

    private func isValidShuffleOrder(_ order: [Int]) -> Bool {
        order.count == songs.count
            && Set(order) == Set(songs.indices)
    }
}
