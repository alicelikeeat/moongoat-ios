import Foundation

public struct Card: Codable, Identifiable, Equatable, Sendable {
    public let id: Int
    public var kind: Int
    public let x: Double
    public let y: Double
    public let layer: Int
    public init(id: Int, kind: Int, x: Double, y: Double, layer: Int) {
        self.id = id; self.kind = kind; self.x = x; self.y = y; self.layer = layer
    }
}
public enum GameStatus: String, Codable, Sendable { case playing, won, lost }
public struct GameState: Codable, Equatable, Sendable {
    public var board: [Card]
    public var tray: [Card]
    public var matched: Int
    public var status: GameStatus
    public var seed: UInt64
    public var moves: Int
    public var shufflesLeft: Int
}
public enum GameError: Error { case blocked, unavailable, ended, invalidSave }
public struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
public struct Game: Sendable {
    public private(set) var state: GameState
    private var history: [GameState] = []
    public var canUndo: Bool { !history.isEmpty }
    public init(seed: UInt64, rows: Int = 4) {
        let rowCount = min(5, max(3, rows))
        var rng = SeededRandom(seed: seed)
        var cards: [Card] = []
        for layer in 0..<3 {
            for row in 0..<rowCount {
                for col in 0..<4 {
                    cards.append(Card(id: cards.count, kind: 0,
                        x: Double(col) * 1.08 + Double(layer) * 0.22,
                        y: Double(row) * 1.08 + Double(layer) * 0.22, layer: layer))
                }
            }
        }
        // Create a legal removal order first, then assign consecutive triples.
        // This guarantees at least one winning route for every generated seed.
        var pending = cards
        var order: [Int] = []
        while !pending.isEmpty {
            let available = pending.filter { Self.isAvailable($0, on: pending) }
            let selected = available[Int(rng.next() % UInt64(available.count))]
            order.append(selected.id)
            pending.removeAll { $0.id == selected.id }
        }
        for group in 0..<(order.count / 3) {
            let kind = Int(rng.next() % 8)
            for index in 0..<3 { cards[order[group * 3 + index]].kind = kind }
        }
        state = GameState(board: cards, tray: [], matched: 0, status: .playing,
                          seed: seed, moves: 0, shufflesLeft: 2)
    }
    public init(restoring saved: GameState) throws {
        let all = saved.board + saved.tray
        guard all.count <= 60, saved.tray.count <= 7,
            Set(all.map(\.id)).count == all.count,
            saved.matched >= 0, saved.matched % 3 == 0,
            [36, 48, 60].contains(all.count + saved.matched),
            (0...2).contains(saved.shufflesLeft), saved.moves >= 0,
            all.allSatisfy({ (0..<8).contains($0.kind) && (0..<60).contains($0.id)
                && (0..<3).contains($0.layer) && $0.x.isFinite && $0.y.isFinite
                && (0...5).contains($0.x) && (0...6).contains($0.y) }),
            !Dictionary(grouping: saved.tray, by: \.kind).values.contains(where: { $0.count >= 3 }),
            Dictionary(grouping: all, by: \.kind).values.allSatisfy({ $0.count % 3 == 0 })
        else { throw GameError.invalidSave }
        let expected: GameStatus = saved.board.isEmpty && saved.tray.isEmpty ? .won : (saved.tray.count == 7 ? .lost : .playing)
        guard saved.status == expected else { throw GameError.invalidSave }
        state = saved
    }
    public static func isAvailable(_ card: Card, on board: [Card]) -> Bool {
        !board.contains { other in
            other.layer > card.layer && abs(other.x - card.x) < 0.96 && abs(other.y - card.y) < 0.96
        }
    }
    public func isAvailable(_ id: Int) -> Bool {
        guard let card = state.board.first(where: { $0.id == id }) else { return false }
        return Self.isAvailable(card, on: state.board)
    }
    @discardableResult public mutating func pick(_ id: Int) throws -> Int {
        guard state.status == .playing else { throw GameError.ended }
        guard let index = state.board.firstIndex(where: { $0.id == id }) else { throw GameError.unavailable }
        guard isAvailable(id) else { throw GameError.blocked }
        history.append(state)
        if history.count > 60 { history.removeFirst() }
        let card = state.board.remove(at: index)
        let insertion = state.tray.lastIndex(where: { $0.kind == card.kind }).map { $0 + 1 } ?? state.tray.count
        state.tray.insert(card, at: insertion)
        state.moves += 1
        let matches = state.tray.filter { $0.kind == card.kind }
        if matches.count == 3 {
            state.tray.removeAll { $0.kind == card.kind }
            state.matched += 3
        }
        if state.board.isEmpty && state.tray.isEmpty { state.status = .won }
        else if state.tray.count >= 7 { state.status = .lost }
        return matches.count == 3 ? 3 : 0
    }
    public mutating func undo() {
        guard let previous = history.popLast() else { return }
        state = previous
    }
    public mutating func shuffle() throws {
        guard state.status == .playing else { throw GameError.ended }
        guard state.shufflesLeft > 0 else { throw GameError.unavailable }
        history.append(state)
        var rng = SeededRandom(seed: state.seed &+ UInt64(state.moves) &+ UInt64(state.shufflesLeft * 7919))
        let kinds = state.board.map(\.kind).shuffled(using: &rng)
        for index in state.board.indices { state.board[index].kind = kinds[index] }
        state.shufflesLeft -= 1
    }
    public func hint() -> Int? {
        let available = state.board.filter { isAvailable($0.id) }
        return available.max { a, b in
            state.tray.filter { $0.kind == a.kind }.count < state.tray.filter { $0.kind == b.kind }.count
        }?.id
    }
}
