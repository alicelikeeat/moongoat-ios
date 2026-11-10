import Foundation

public struct SavedSession: Codable, Sendable {
    public let version: Int
    public let game: GameState
    public init(game: GameState) { version = 1; self.game = game }
}
/// Encoding and atomic I/O execute on this actor, not the UI actor. Revisions
/// prevent an older asynchronous request from overwriting a newer snapshot.
public actor OrderedSessionStore {
    private let url: URL
    private var writtenRevision: UInt64 = 0
    public init(url: URL) { self.url = url }
    @discardableResult public func write(_ state: GameState, revision: UInt64) throws -> Bool {
        guard revision > writtenRevision else { return false }
        let data = try JSONEncoder().encode(SavedSession(game: state))
        try data.write(to: url, options: .atomic)
        writtenRevision = revision
        return true
    }
}
