import XCTest
@testable import MoonGoatCore
@MainActor final class SessionStoreTests: XCTestCase {
    func testLateOlderWriteCannotOverwriteLatestSave() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = OrderedSessionStore(url: url)
        var game = Game(seed: 2026)
        let before = game.state
        try game.pick(XCTUnwrap(game.hint()))
        let latest = game.state
        let newestWritten = try await store.write(latest, revision: 2)
        let staleWritten = try await store.write(before, revision: 1)
        XCTAssertTrue(newestWritten)
        XCTAssertFalse(staleWritten)
        let saved = try JSONDecoder().decode(SavedSession.self, from: Data(contentsOf: url))
        XCTAssertEqual(saved.version, 1)
        XCTAssertEqual(try Game(restoring: saved.game).state, latest)
    }
    func testFailedWriteCanRetrySameRevision() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("save.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OrderedSessionStore(url: url)
        let state = Game(seed: 1).state
        do { try await store.write(state, revision: 1); XCTFail("Expected missing directory failure") }
        catch { }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let written = try await store.write(state, revision: 1)
        XCTAssertTrue(written)
        XCTAssertEqual(try JSONDecoder().decode(SavedSession.self, from: Data(contentsOf: url)).game, state)
    }
    func testManyConcurrentSnapshotsKeepHighestRevision() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = OrderedSessionStore(url: url)
        let states = (1...20).map { Game(seed: UInt64($0)).state }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, state) in states.enumerated().reversed() {
                group.addTask { try await store.write(state, revision: UInt64(index + 1)) }
            }
            try await group.waitForAll()
        }
        XCTAssertEqual(try JSONDecoder().decode(SavedSession.self, from: Data(contentsOf: url)).game, states.last)
    }
}
