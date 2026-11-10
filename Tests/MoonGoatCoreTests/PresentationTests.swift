import XCTest
@testable import MoonGoatCore
final class PresentationTests: XCTestCase {
    private func fixture() throws -> Game {
        let board = (0..<36).map { Card(id: $0, kind: ($0 / 3) % 8, x: 0, y: 0, layer: 0) }
        return try Game(restoring: GameState(board: board, tray: [], matched: 0, status: .playing, seed: 1, moves: 0, shufflesLeft: 2))
    }
    func testMatchingTripleExistsOnlyInPresentation() throws {
        var game = try fixture()
        try game.pick(0); try game.pick(1)
        let before = game.state
        try game.pick(2)
        let committed = game.state
        let plan = try XCTUnwrap(PickPresentation(before: before, after: committed, pickedID: 2))
        XCTAssertEqual(plan.matchingIDs, Set([0, 1, 2]))
        XCTAssertEqual(plan.collected.tray.map(\.id), [0, 1, 2])
        XCTAssertEqual(plan.collected.matched, before.matched)
        XCTAssertTrue(committed.tray.isEmpty)
        XCTAssertEqual(try Game(restoring: committed).state, committed)
        XCTAssertThrowsError(try Game(restoring: plan.collected))
        game.undo()
        XCTAssertEqual(game.state, before)
        let reverse = try XCTUnwrap(PickPresentation(before: game.state, after: committed, pickedID: 2))
        XCTAssertEqual(reverse.collected, plan.collected)
    }
    func testOrdinaryPickAndInvalidTransition() throws {
        var game = try fixture()
        let before = game.state
        try game.pick(0)
        let plan = try XCTUnwrap(PickPresentation(before: before, after: game.state, pickedID: 0))
        XCTAssertTrue(plan.matchingIDs.isEmpty)
        XCTAssertEqual(plan.collected, game.state)
        XCTAssertNil(PickPresentation(before: before, after: before, pickedID: 0))
        XCTAssertNil(PickPresentation(before: before, after: game.state, pickedID: -1))
    }
    func testFinalTripleDoesNotPresentWinUntilSettled() throws {
        var game = try fixture()
        for id in 0..<35 { try game.pick(id) }
        let before = game.state
        try game.pick(35)
        let plan = try XCTUnwrap(PickPresentation(before: before, after: game.state, pickedID: 35))
        XCTAssertEqual(plan.matchingIDs.count, 3)
        XCTAssertEqual(plan.collected.status, .playing)
        XCTAssertEqual(game.state.status, .won)
        XCTAssertEqual(plan.collected.board.count + plan.collected.tray.count + plan.collected.matched, 36)
    }
}
