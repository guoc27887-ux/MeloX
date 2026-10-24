import Foundation

enum RepeatMode: String, CaseIterable, Identifiable {
    case off
    case all
    case one

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .off, .all: "repeat"
        case .one: "repeat.1"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .off: L10n.string("ui.player.repeat.off")
        case .all: L10n.string("ui.player.repeat.all")
        case .one: L10n.string("ui.player.repeat.one")
        }
    }
}

enum QueuePlaybackModeIndicator: String {
    case shuffle
    case repeatAll
    case repeatOne
    case autoplay
    case autoMix

    var systemImage: String {
        switch self {
        case .shuffle:
            "shuffle"
        case .repeatAll:
            "repeat"
        case .repeatOne:
            "repeat.1"
        case .autoplay:
            "infinity"
        case .autoMix:
            "circle.circle.fill"
        }
    }
}

struct PlaybackQueue {
    private(set) var songs: [Song] = []
    private(set) var currentIndex = 0
    private(set) var isShuffled = false

    private var shuffledOrder: [Int] = []
    private var shuffledPosition = 0

    var currentSong: Song? {
        guard songs.indices.contains(currentIndex) else { return nil }
        return songs[currentIndex]
    }

    var persistedShuffleOrder: [Int] {
        shuffledOrder
    }

    func upcomingIndices(wraps: Bool) -> [Int] {
        guard !songs.isEmpty else { return [] }
        let order = isShuffled
            ? shuffledOrder
            : Array(songs.indices)
        let position = isShuffled
            ? shuffledPosition
            : currentIndex
        let nextPosition = min(position + 1, order.count)
        let remaining = Array(order.dropFirst(nextPosition))
        guard wraps, position > 0 else { return remaining }
        return remaining + Array(order.prefix(position))
    }

    mutating func restore(
        songs: [Song],
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
            shuffledPosition = shuffledOrder.firstIndex(of: self.currentIndex) ?? 0
        } else if isShuffled {
            rebuildShuffleOrder()
        } else {
            self.shuffledOrder = []
            shuffledPosition = 0
        }
    }

    mutating func replace(with songs: [Song], startingAt index: Int) {
        self.songs = songs
        currentIndex = songs.isEmpty ? 0 : min(max(index, 0), songs.count - 1)
        if isShuffled {
            rebuildShuffleOrder()
        }
    }

    mutating func select(index: Int) -> Bool {
        guard songs.indices.contains(index) else { return false }
        currentIndex = index
        alignShufflePosition()
        return true
    }

    mutating func move(by offset: Int, wraps: Bool) -> Bool {
        let order = isShuffled ? shuffledOrder : Array(songs.indices)
        guard !order.isEmpty else { return false }
        let position = isShuffled ? shuffledPosition : currentIndex
        var destination = position + offset
        if order.indices.contains(destination) {
            // Continue in the existing order.
        } else if wraps {
            destination = offset > 0 ? 0 : order.count - 1
        } else {
            return false
        }

        if isShuffled {
            shuffledPosition = destination
            currentIndex = order[destination]
        } else {
            currentIndex = destination
        }
        return true
    }

    func canMove(by offset: Int, wraps: Bool) -> Bool {
        let order = isShuffled ? shuffledOrder : Array(songs.indices)
        guard !order.isEmpty else { return false }
        let position = isShuffled ? shuffledPosition : currentIndex
        return order.indices.contains(position + offset) || wraps
    }

    mutating func toggleShuffle() {
        isShuffled.toggle()
        if isShuffled {
            rebuildShuffleOrder()
        } else {
            shuffledOrder = []
            shuffledPosition = 0
        }
    }

    mutating func append(_ song: Song) {
        append(contentsOf: [song])
    }

    mutating func append(contentsOf newSongs: [Song]) {
        guard !newSongs.isEmpty else { return }
        let firstNewIndex = songs.count
        songs.append(contentsOf: newSongs)
        guard isShuffled else { return }

        let newIndices = Array(firstNewIndex..<songs.count).shuffled()
        shuffledOrder.append(contentsOf: newIndices)
    }

    mutating func insertNext(_ song: Song) {
        guard !songs.isEmpty else {
            append(song)
            return
        }

        let insertionIndex = min(currentIndex + 1, songs.endIndex)
        songs.insert(song, at: insertionIndex)

        guard isShuffled else { return }

        shuffledOrder = shuffledOrder.map { index in
            index >= insertionIndex ? index + 1 : index
        }
        let shuffledInsertionIndex = min(
            shuffledPosition + 1,
            shuffledOrder.endIndex
        )
        shuffledOrder.insert(
            insertionIndex,
            at: shuffledInsertionIndex
        )
    }

    mutating func moveUpcomingSongs(
        fromOffsets source: IndexSet,
        toOffset destination: Int,
        wraps: Bool
    ) {
        if isShuffled {
            var positions = Array(
                shuffledOrder.indices.dropFirst(
                    min(shuffledPosition + 1, shuffledOrder.count)
                )
            )
            if wraps, shuffledPosition > 0 {
                positions.append(
                    contentsOf: shuffledOrder.indices.prefix(
                        shuffledPosition
                    )
                )
            }
            let upcomingOrder = moved(
                positions.map { shuffledOrder[$0] },
                fromOffsets: source,
                toOffset: destination
            )
            for (position, songIndex) in zip(
                positions,
                upcomingOrder
            ) {
                shuffledOrder[position] = songIndex
            }
            return
        }

        var positions = Array(
            songs.indices.dropFirst(
                min(currentIndex + 1, songs.count)
            )
        )
        if wraps, currentIndex > 0 {
            positions.append(
                contentsOf: songs.indices.prefix(currentIndex)
            )
        }
        let upcomingSongs = moved(
            positions.map { songs[$0] },
            fromOffsets: source,
            toOffset: destination
        )
        for (position, song) in zip(positions, upcomingSongs) {
            songs[position] = song
        }
    }

    private mutating func rebuildShuffleOrder() {
        guard songs.indices.contains(currentIndex) else {
            shuffledOrder = []
            shuffledPosition = 0
            return
        }
        shuffledOrder = [currentIndex] + songs.indices.filter { $0 != currentIndex }.shuffled()
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
        order.count == songs.count && Set(order) == Set(songs.indices)
    }

    private func moved<Element>(
        _ elements: [Element],
        fromOffsets source: IndexSet,
        toOffset destination: Int
    ) -> [Element] {
        let validSource = source
            .filter(elements.indices.contains)
            .sorted()
        guard !validSource.isEmpty else { return elements }

        var result = elements
        let movingElements = validSource.map { elements[$0] }
        for index in validSource.reversed() {
            result.remove(at: index)
        }

        let removedBeforeDestination = validSource.filter {
            $0 < destination
        }.count
        let insertionIndex = min(
            max(destination - removedBeforeDestination, 0),
            result.count
        )
        result.insert(contentsOf: movingElements, at: insertionIndex)
        return result
    }
}
