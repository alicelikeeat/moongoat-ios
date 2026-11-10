import Foundation

public enum BoardDifficulty: String, CaseIterable, Sendable {
    case relaxed, standard, expert
    public var cardCount: Int { switch self { case .relaxed: 108; case .standard: 240; case .expert: 360 } }
    public var kindCount: Int { switch self { case .relaxed: 12; case .standard: 16; case .expert: 20 } }
    public var layerCount: Int { switch self { case .relaxed: 5; case .standard: 8; case .expert: 12 } }
    public var reservePerSide: Int { switch self { case .relaxed: 9; case .standard: 12; case .expert: 18 } }
}
public enum CardCatalog {
    public static let kindCount = 20
    public static let tileSize = 0.96
}
public struct BoardBounds: Sendable {
    public let width: Double
    public let height: Double
}
extension GameState {
    public var totalCards: Int { board.count + tray.count + matched }
    public var kindCount: Int {
        BoardDifficulty.allCases.first { $0.cardCount == totalCards }?.kindCount ?? 8
    }
    // Fixed for the entire session: removing edge tiles never resizes the board.
    public var boardBounds: BoardBounds {
        if [36, 48, 60].contains(totalCards) {
            return BoardBounds(width: 4.64, height: Double(totalCards / 12 - 1) * 1.08 + 1.44)
        }
        return BoardBounds(width: 7.35, height: 7.05)
    }
}
struct GeneratedBoard {
    let cards: [Card]
    let winningRoute: [Int]
}
enum BoardGenerator {
    static func overlaps(_ a: Card, _ b: Card) -> Bool {
        abs(a.x - b.x) < CardCatalog.tileSize && abs(a.y - b.y) < CardCatalog.tileSize
    }
    static func generate(seed: UInt64, difficulty: BoardDifficulty) -> GeneratedBoard {
        var geometryRNG = SeededRandom(seed: seed ^ 0x67656f6d65747279)
        var cards: [Card] = []
        let mainCount = difficulty.cardCount - 2 * difficulty.reservePerSide
        let quota = mainCount / difficulty.layerCount
        for layer in 0..<difficulty.layerCount {
            // Select an irregular terrace from a six-by-six lattice. Holes and
            // two-lobe masks vary by seed and depth; planes never self-overlap.
            let pattern = Int((seed &+ UInt64(layer)) % 4)
            var candidates: [(col: Int, row: Int, score: Double)] = []
            for row in 0..<6 {
                for col in 0..<6 {
                    let x = Double(col), y = Double(row)
                    let score: Double
                    switch pattern {
                    case 0: score = pow(x - 2.5, 2) * 0.85 + pow(y - 2.5, 2)
                    case 1: score = min(pow(x - 1, 2) + pow(y - 1.7, 2), pow(x - 4, 2) + pow(y - 3.3, 2))
                    case 2: score = abs(hypot(x - 2.5, y - 2.5) - 2.0) * 3
                    default: score = abs(x - 2.5) + abs(y - 2.5) * 1.2 + ((col + row + layer) % 3 == 0 ? 1.5 : 0)
                    }
                    let jitter = Double(geometryRNG.next() % 100) / 500
                    candidates.append((col, row, score + jitter))
                }
            }
            candidates.sort { $0.score < $1.score }
            for cell in candidates.prefix(quota) {
                let offsetX = layer.isMultiple(of: 2) ? 0.0 : 0.18
                let offsetY = layer % 3 == 0 ? 0.0 : 0.16
                let lobeGap = pattern == 1 && cell.col >= 3 ? 0.14 : 0.0
                cards.append(Card(id: cards.count, kind: 0,
                    x: 0.25 + Double(cell.col) * 1.04 + offsetX + lobeGap,
                    y: 0.12 + Double(cell.row) * 1.04 + offsetY,
                    layer: layer))
            }
        }
        // Two visible stepped reserve stacks sit at the lower outer edges.
        for side in 0..<2 {
            for depth in 0..<difficulty.reservePerSide {
                let drift = Double(depth) * 0.012
                cards.append(Card(id: cards.count, kind: 0,
                    x: side == 0 ? 0.04 + drift : 6.25 - drift,
                    y: 5.80 + drift, layer: difficulty.layerCount + depth))
            }
        }
        // Compute a dependency graph once, rather than repeatedly scanning all
        // pairs after each removal. Available nodes are selected deterministically.
        var blockerCounts = [Int](repeating: 0, count: cards.count)
        var releases = [[Int]](repeating: [], count: cards.count)
        for lower in cards {
            for upper in cards where upper.layer > lower.layer && overlaps(upper, lower) {
                blockerCounts[lower.id] += 1
                releases[upper.id].append(lower.id)
            }
        }
        var routeRNG = SeededRandom(seed: seed ^ 0x726f757465)
        var available = cards.indices.filter { blockerCounts[$0] == 0 }
        var order: [Int] = []
        while !available.isEmpty {
            let selected = available.remove(at: Int(routeRNG.next() % UInt64(available.count)))
            order.append(selected)
            for released in releases[selected] {
                blockerCounts[released] -= 1
                if blockerCounts[released] == 0 { available.append(released) }
            }
        }
        precondition(order.count == difficulty.cardCount)
        // Balanced, shuffled triple identities guarantee all advertised types
        // occur, while a legal route with at most three occupied slots remains.
        var kinds = (0..<(order.count / 3)).map { $0 % difficulty.kindCount }
        kinds.shuffle(using: &routeRNG)
        for group in kinds.indices {
            for index in 0..<3 { cards[order[group * 3 + index]].kind = kinds[group] }
        }
        return GeneratedBoard(cards: cards, winningRoute: order)
    }
}
