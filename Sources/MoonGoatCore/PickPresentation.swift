/// Transient animation data; never persisted or restored as a legal game state.
/// The rules commit immediately. The UI can briefly display a matching triple.
public struct PickPresentation: Sendable {
    public let collected: GameState
    public let matchingIDs: Set<Int>
    public let arrivingID: Int

    public init?(before: GameState, after: GameState, pickedID: Int) {
        guard let card = before.board.first(where: { $0.id == pickedID }),
              after.moves == before.moves + 1,
              after.board == before.board.filter({ $0.id != pickedID }) else { return nil }
        var collected = after
        collected.tray = before.tray
        let insertion = collected.tray.lastIndex(where: { $0.kind == card.kind }).map { $0 + 1 } ?? collected.tray.count
        collected.tray.insert(card, at: insertion)
        let group = collected.tray.filter { $0.kind == card.kind }
        matchingIDs = after.matched == before.matched + 3 && group.count == 3 ? Set(group.map(\.id)) : []
        collected.matched = before.matched
        collected.status = .playing
        self.collected = collected
        arrivingID = card.id
    }
}
