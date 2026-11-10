/// Stable geometry for a session, shared by all its presentation frames.
public struct BoardSnapshot: Equatable, Sendable {
    public let cards: [Card]
    public let availableIDs: Set<Int>
    public static let empty = BoardSnapshot(cards: [], availableIDs: [])
}
public struct BoardIndex: Sendable {
    private let order: [Int]
    private let blockers: [Int: [Int]]
    private let exactCovers: [Int: [Int]]
    public init(cards: [Card]) {
        order = cards.sorted { $0.layer == $1.layer ? $0.id < $1.id : $0.layer < $1.layer }.map(\.id)
        var blockers: [Int: [Int]] = [:]
        var exactCovers: [Int: [Int]] = [:]
        for lower in cards {
            let above = cards.filter { $0.layer > lower.layer && BoardGenerator.overlaps($0, lower) }
            blockers[lower.id] = above.map(\.id)
            // Only cull identical opaque tile footprints. Partial coverage is
            // retained, including rounded corners and visible layer edges.
            exactCovers[lower.id] = above.filter { $0.x == lower.x && $0.y == lower.y }.map(\.id)
        }
        self.blockers = blockers
        self.exactCovers = exactCovers
    }
    public func snapshot(board: [Card]) -> BoardSnapshot {
        let byID = Dictionary(uniqueKeysWithValues: board.map { ($0.id, $0) })
        let active = Set(byID.keys)
        var available: Set<Int> = []
        var visible: [Card] = []
        for id in order where active.contains(id) {
            if !(blockers[id] ?? []).contains(where: { active.contains($0) }) { available.insert(id) }
            if !(exactCovers[id] ?? []).contains(where: { active.contains($0) }), let card = byID[id] {
                visible.append(card)
            }
        }
        return BoardSnapshot(cards: visible, availableIDs: available)
    }
}
