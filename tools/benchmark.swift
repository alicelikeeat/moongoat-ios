// Compile alongside Sources/MoonGoatCore/*.swift with swiftc -O.
import Foundation
@main struct BoardBenchmark {
    static func main() {
        let game = Game(seed: 2026, difficulty: .expert)
        let board = game.state.board
        let index = BoardIndex(cards: board)
        let iterations = 500
        var checksum = 0
        let oldStart = ProcessInfo.processInfo.systemUptime
        for _ in 0..<iterations {
            let available = Set(board.filter { Game.isAvailable($0, on: board) }.map(\.id))
            let sorted = board.sorted { $0.layer < $1.layer }
            checksum += available.count + sorted.count
        }
        let oldTime = ProcessInfo.processInfo.systemUptime - oldStart
        let newStart = ProcessInfo.processInfo.systemUptime
        for _ in 0..<iterations {
            let snapshot = index.snapshot(board: board)
            checksum += snapshot.availableIDs.count + snapshot.cards.count
        }
        let newTime = ProcessInfo.processInfo.systemUptime - newStart
        let snapshot = index.snapshot(board: board)
        let data: [String: Any] = ["seed": 2026, "tiles": board.count, "iterations": iterations,
            "old_ms_per_refresh": oldTime * 1000 / Double(iterations),
            "indexed_ms_per_refresh": newTime * 1000 / Double(iterations),
            "retained_tiles": snapshot.cards.count, "flight_geometry_tiles": snapshot.availableIDs.count,
            "checksum": checksum]
        print(String(data: try! JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]), encoding: .utf8)!)
    }
}
