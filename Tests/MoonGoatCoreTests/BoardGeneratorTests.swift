import XCTest
@testable import MoonGoatCore
final class BoardGeneratorTests: XCTestCase {
    func testCountsTypesBoundsAndLayerSeparation() throws {
        for difficulty in BoardDifficulty.allCases {
            for seed in 0..<20 {
                let game = Game(seed: UInt64(seed), difficulty: difficulty)
                let board = game.state.board
                XCTAssertEqual(board.count, difficulty.cardCount)
                XCTAssertEqual(Set(board.map(\.kind)), Set(0..<difficulty.kindCount))
                XCTAssertEqual(Set(board.map(\.id)).count, difficulty.cardCount)
                let kinds = Dictionary(grouping: board, by: \.kind)
                XCTAssertTrue(kinds.values.allSatisfy { $0.count % 3 == 0 })
                XCTAssertLessThanOrEqual((kinds.values.map(\.count).max() ?? 0) - (kinds.values.map(\.count).min() ?? 0), 3)
                let mainCount = difficulty.cardCount - difficulty.reservePerSide * 2
                let main = Array(board.prefix(mainCount))
                let reserves = Array(board.suffix(difficulty.reservePerSide * 2))
                XCTAssertEqual(Set(main.map(\.layer)).count, difficulty.layerCount)
                XCTAssertEqual(reserves.filter { $0.x < 1 }.count, difficulty.reservePerSide)
                XCTAssertEqual(reserves.filter { $0.x > 6 }.count, difficulty.reservePerSide)
                let bounds = game.state.boardBounds
                for card in board {
                    XCTAssertGreaterThanOrEqual(card.x, 0)
                    XCTAssertGreaterThanOrEqual(card.y, 0)
                    XCTAssertLessThanOrEqual(card.x + CardCatalog.tileSize, bounds.width)
                    XCTAssertLessThanOrEqual(card.y + CardCatalog.tileSize, bounds.height)
                    for other in board where other.id != card.id && other.layer == card.layer {
                        XCTAssertFalse(BoardGenerator.overlaps(card, other), "Same-plane overlap")
                    }
                }
                XCTAssertEqual(try Game(restoring: game.state).state, game.state)
                for side in [reserves.filter { $0.x < 1 }, reserves.filter { $0.x > 6 }] {
                    let top = try XCTUnwrap(side.max { $0.layer < $1.layer })
                    XCTAssertTrue(game.isAvailable(top.id))
                    XCTAssertTrue(side.filter { $0.id != top.id }.allSatisfy { !game.isAvailable($0.id) })
                }
            }
        }
    }
    func testLayoutVariesAndBoundsStayFixed() throws {
        var game = Game(seed: 2026)
        let other = Game(seed: 2027)
        XCTAssertNotEqual(game.state.board.map(\.x), other.state.board.map(\.x))
        let bounds = game.state.boardBounds
        let route = BoardGenerator.generate(seed: 2026, difficulty: .standard).winningRoute
        for id in route.prefix(60) { try game.pick(id) }
        XCTAssertEqual(game.state.boardBounds.width, bounds.width)
        XCTAssertEqual(game.state.boardBounds.height, bounds.height)
    }
    func testLegacySnapshotsAndExpandedCustomKindSurviveRoundTrip() throws {
        for total in [36, 48, 60] {
            let cards = (0..<total).map { Card(id: $0, kind: ($0 / 3) % 8, x: Double($0 % 4), y: 0, layer: 0) }
            let saved = GameState(board: cards, tray: [], matched: 0, status: .playing, seed: 2026, moves: 0, shufflesLeft: 2)
            let data = try JSONEncoder().encode(saved)
            let restored = try Game(restoring: JSONDecoder().decode(GameState.self, from: data))
            XCTAssertEqual(restored.state, saved)
            XCTAssertEqual(restored.state.kindCount, 8)
            XCTAssertEqual(restored.state.boardBounds.width, 4.64)
        }
        var game = Game(seed: 2026, difficulty: .expert)
        let route = BoardGenerator.generate(seed: 2026, difficulty: .expert).winningRoute
        for id in route.prefix(30) { try game.pick(id) }
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(game.state))
        XCTAssertEqual(try Game(restoring: decoded).state, game.state)
        XCTAssertTrue(game.state.board.contains { $0.kind == 19 })
        var invalid = game.state
        let card = invalid.board[0]
        invalid.board[0] = Card(id: card.id, kind: 20, x: card.x, y: card.y, layer: card.layer)
        XCTAssertThrowsError(try Game(restoring: invalid))
    }
}
