import XCTest
@testable import MoonGoatCore
final class GameTests: XCTestCase {
    func testDeterminismAndInventory() throws {
        for seed in 0..<100 {
            let game = Game(seed: UInt64(seed))
            XCTAssertEqual(game.state, Game(seed: UInt64(seed)).state)
            XCTAssertEqual(game.state.board.count, 48)
            XCTAssertTrue(Dictionary(grouping: game.state.board, by: \.kind).values.allSatisfy { $0.count % 3 == 0 })
            XCTAssertTrue(game.state.board.contains { game.isAvailable($0.id) })
        }
    }
    func testGeneratedWinningRouteFor100SeedsAndAllSizes() throws {
        for rows in 3...5 {
            for seed in 0..<100 {
                var game = Game(seed: UInt64(seed), rows: rows)
                var rng = SeededRandom(seed: UInt64(seed))
                while !game.state.board.isEmpty {
                    let available = game.state.board.filter { game.isAvailable($0.id) }
                    let card = available[Int(rng.next() % UInt64(available.count))]
                    try game.pick(card.id)
                }
                XCTAssertEqual(game.state.status, .won, "seed \(seed) rows \(rows)")
            }
        }
    }
    func testBlockedPickIsAtomic() throws {
        var game = Game(seed: 12)
        let before = game.state
        let blocked = try XCTUnwrap(game.state.board.first { !game.isAvailable($0.id) })
        XCTAssertThrowsError(try game.pick(blocked.id))
        XCTAssertEqual(before, game.state)
        XCTAssertThrowsError(try game.pick(-1))
    }
    func testMatchUndoAndWin() throws {
        var board = (0..<36).map { Card(id: $0, kind: ($0 / 3) % 8, x: Double($0 % 4), y: Double(($0 / 4) % 5), layer: 0) }
        let state = GameState(board: board, tray: [], matched: 0, status: .playing, seed: 1, moves: 0, shufflesLeft: 2)
        var game = try Game(restoring: state)
        try game.pick(0); try game.pick(1)
        let before = game.state
        XCTAssertEqual(try game.pick(2), 3)
        XCTAssertTrue(game.state.tray.isEmpty)
        game.undo(); XCTAssertEqual(before, game.state)
        try game.pick(2)
        board.removeFirst(3)
        for card in board { try game.pick(card.id) }
        XCTAssertEqual(game.state.status, .won)
        XCTAssertEqual(game.state.matched, 36)
        XCTAssertThrowsError(try game.pick(0))
    }
    func testSeventhCardMatchesBeforeLoss() throws {
        let original = (0..<36).map { Card(id: $0, kind: ($0 / 3) % 8, x: 0, y: 0, layer: 0) }
        var game = try Game(restoring: GameState(board: original, tray: [], matched: 0, status: .playing, seed: 1, moves: 0, shufflesLeft: 2))
        for id in [0, 1, 3, 6, 9, 12] { try game.pick(id) }
        XCTAssertEqual(game.state.tray.count, 6)
        XCTAssertEqual(try game.pick(2), 3)
        XCTAssertEqual(game.state.tray.count, 4)
        XCTAssertEqual(game.state.status, .playing)
    }
    func testLoseAndUndo() throws {
        let board = (0..<36).map { Card(id: $0, kind: ($0 / 3) % 8, x: 0, y: 0, layer: 0) }
        var game = try Game(restoring: GameState(board: board, tray: [], matched: 0, status: .playing, seed: 1, moves: 0, shufflesLeft: 2))
        for id in stride(from: 0, to: 21, by: 3) { try game.pick(id) }
        XCTAssertEqual(game.state.status, .lost)
        game.undo(); XCTAssertEqual(game.state.status, .playing)
        XCTAssertEqual(game.state.tray.count, 6)
    }
    func testShuffleConservesCardsAndBudget() throws {
        var game = Game(seed: 99)
        let before = game.state
        try game.shuffle()
        XCTAssertEqual(game.state.board.map(\.kind).sorted(), before.board.map(\.kind).sorted())
        XCTAssertEqual(game.state.board.map(\.id), before.board.map(\.id))
        game.undo(); XCTAssertEqual(game.state, before)
        try game.shuffle(); try game.shuffle()
        let exhausted = game.state
        XCTAssertThrowsError(try game.shuffle())
        XCTAssertEqual(exhausted, game.state)
    }
    func testSaveRoundTripAndValidation() throws {
        var game = Game(seed: 42)
        try game.pick(XCTUnwrap(game.hint()))
        let data = try JSONEncoder().encode(game.state)
        let restored = try Game(restoring: JSONDecoder().decode(GameState.self, from: data))
        XCTAssertEqual(restored.state, game.state)
        var broken = game.state
        broken.board.append(broken.board[0])
        XCTAssertThrowsError(try Game(restoring: broken))
        broken = game.state; broken.status = .won
        XCTAssertThrowsError(try Game(restoring: broken))
    }
}
