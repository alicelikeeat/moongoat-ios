import XCTest
@testable import MoonGoatCore
final class BoardIndexTests: XCTestCase {
    func testCachedAvailabilityMatchesRulesThroughPicksUndoAndShuffle() throws {
        for difficulty in BoardDifficulty.allCases {
            for seed in 0..<10 {
                var game = Game(seed: UInt64(seed), difficulty: difficulty)
                let index = BoardIndex(cards: game.state.board)
                let route = BoardGenerator.generate(seed: UInt64(seed), difficulty: difficulty).winningRoute
                for id in route {
                    let snapshot = index.snapshot(board: game.state.board)
                    let expected = Set(game.state.board.filter { game.isAvailable($0.id) }.map(\.id))
                    XCTAssertEqual(snapshot.availableIDs, expected)
                    XCTAssertTrue(expected.isSubset(of: Set(snapshot.cards.map(\.id))))
                    try game.pick(id)
                }
                game.undo()
                try game.shuffle()
                let snapshot = index.snapshot(board: game.state.board)
                XCTAssertEqual(snapshot.availableIDs, Set(game.state.board.filter { game.isAvailable($0.id) }.map(\.id)))
                for card in snapshot.cards {
                    XCTAssertEqual(card, game.state.board.first { $0.id == card.id })
                }
            }
        }
    }
    func testOnlyExactlyCoveredCardsAreCulledAndRevealAfterRemoval() {
        let lower = Card(id: 0, kind: 0, x: 0, y: 0, layer: 0)
        let upper = Card(id: 1, kind: 1, x: 0, y: 0, layer: 1)
        let partial = Card(id: 2, kind: 2, x: 0.5, y: 0.5, layer: 2)
        let index = BoardIndex(cards: [lower, upper, partial])
        let snapshot = index.snapshot(board: [lower, upper, partial])
        XCTAssertEqual(snapshot.cards.map(\.id), [1, 2])
        XCTAssertEqual(index.snapshot(board: [lower, partial]).cards.map(\.id), [0, 2])
        XCTAssertEqual(index.snapshot(board: [lower]).availableIDs, Set([0]))
        XCTAssertEqual(index.snapshot(board: [lower]).cards, [lower])
    }
    func testDenseBoardActuallyReducesRetainedCards() {
        let game = Game(seed: 2026, difficulty: .expert)
        let snapshot = BoardIndex(cards: game.state.board).snapshot(board: game.state.board)
        XCTAssertLessThan(snapshot.cards.count, game.state.board.count)
        XCTAssertEqual(game.state.board.count, 360)
    }
}
