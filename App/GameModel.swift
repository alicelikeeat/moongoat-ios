import SwiftUI
import MoonGoatCore
import ImageIO

@MainActor final class GameModel: ObservableObject {
    @Published private(set) var game: Game
    @Published var theme: FaceTheme = .meadow { didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") } }
    @Published var customFaces: [Int: UIImage] = [:]
    private(set) var faceRevision = 0
    @Published private(set) var boardSnapshot: BoardSnapshot = .empty
    @Published var notice: String?
    @Published var hintID: Int?
    @Published var celebration = 0
    @Published var haptics = true
    @Published private(set) var animationState: GameState? { didSet { refreshBoard() } }
    @Published private(set) var mergingIDs: Set<Int> = []
    @Published private(set) var isAnimating = false
    var visibleState: GameState { animationState ?? game.state }
    private var animationTask: Task<Void, Never>?
    private var savesBlocked = false
    private let directory: URL
    private let saveURL: URL
    private let sessionStore: OrderedSessionStore
    private var saveRevision: UInt64 = 0
    private var boardIndex = BoardIndex(cards: [])

    init() {
        directory = URL.documentsDirectory.appending(path: "MoonGoat", directoryHint: .isDirectory)
        saveURL = directory.appending(path: "session.json")
        sessionStore = OrderedSessionStore(url: saveURL)
        game = Game(seed: UInt64.random(in: 1...UInt64.max))
        theme = FaceTheme(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "") ?? .meadow
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: saveURL.path) {
                let envelope = try JSONDecoder().decode(Session.self, from: Data(contentsOf: saveURL))
                guard envelope.version == 1 else { throw GameError.invalidSave }
                game = try Game(restoring: envelope.game)
            }
            for kind in 0..<CardCatalog.kindCount {
                let url = directory.appending(path: "face-\(kind).png")
                if let image = UIImage(contentsOfFile: url.path) { customFaces[kind] = image.preparingForDisplay() ?? image }
            }
        } catch {
            savesBlocked = true
            notice = "存档未能读取，已保留原文件。开始新局后才会重新保存。"
        }
        refreshBoard(rebuild: true)
    }
    typealias Session = SavedSession
    private func refreshBoard(rebuild: Bool = false) {
        if rebuild { boardIndex = BoardIndex(cards: game.state.board) }
        let updated = boardIndex.snapshot(board: visibleState.board)
        if updated != boardSnapshot { boardSnapshot = updated }
    }
    @discardableResult func save() -> Task<Void, Never>? {
        guard !savesBlocked else { return nil }
        saveRevision += 1
        let revision = saveRevision
        let state = game.state
        let store = sessionStore
        return Task { @MainActor [weak self] in
            do { try await store.write(state, revision: revision) }
            catch { self?.notice = "保存失败：\(error.localizedDescription)" }
        }
    }
    func saveForBackground() {
        let token = UIApplication.shared.beginBackgroundTask(withName: "MoonGoat save", expirationHandler: nil)
        let pending = save()
        Task { @MainActor in
            await pending?.value
            if token != .invalid { UIApplication.shared.endBackgroundTask(token) }
        }
    }
    func newGame(difficulty: BoardDifficulty = .standard) {
        finishAnimations()
        if savesBlocked, FileManager.default.fileExists(atPath: saveURL.path) {
            do {
                try FileManager.default.copyItem(at: saveURL, to: directory.appending(path: "unreadable-\(UUID().uuidString).json"))
            } catch { notice = "无法备份旧存档，未开始新局。"; return }
        }
        savesBlocked = false
        game = Game(seed: UInt64.random(in: 1...UInt64.max), difficulty: difficulty)
        refreshBoard(rebuild: true)
        hintID = nil
        save()
    }
    // Cancel only presentation. The game and save always contain a complete transaction.
    func finishAnimations() {
        animationTask?.cancel()
        animationTask = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            animationState = nil
            mergingIDs = []
            isAnimating = false
        }
    }
    func pick(_ id: Int, animated: Bool = true) {
        guard !isAnimating else { return }
        let before = game.state
        do {
            let count = try game.pick(id)
            refreshBoard()
            hintID = nil
            save()
            if haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            guard animated, count == 3,
                  let plan = PickPresentation(before: before, after: game.state, pickedID: id) else {
                if count > 0 { celebration += 1 }
                return
            }
            animationState = plan.collected
            isAnimating = true
            animationTask = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: .milliseconds(150))
                    guard let self, !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                        self.mergingIDs = plan.matchingIDs
                    }
                    try await Task.sleep(for: .milliseconds(190))
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.88)) {
                        self.animationState = nil
                        self.mergingIDs = []
                        self.celebration += 1
                    }
                    try await Task.sleep(for: .milliseconds(70))
                    guard !Task.isCancelled else { return }
                    self.isAnimating = false
                    self.animationTask = nil
                } catch { /* finishAnimations owns cleanup after cancellation. */ }
            }
        } catch { if haptics { UINotificationFeedbackGenerator().notificationOccurred(.warning) } }
    }
    func undo(animated: Bool = true) {
        guard !isAnimating, game.canUndo else { return }
        let committed = game.state
        game.undo()
        refreshBoard()
        hintID = nil
        save()
        guard animated,
              let returned = game.state.board.first(where: { card in !committed.board.contains(where: { $0.id == card.id }) }),
              let plan = PickPresentation(before: game.state, after: committed, pickedID: returned.id),
              !plan.matchingIDs.isEmpty else { return }
        isAnimating = true
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            animationState = plan.collected
            mergingIDs = plan.matchingIDs
        }
        animationTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(30))
                guard let self, !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                    self.mergingIDs = []
                }
                try await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                    self.animationState = nil
                }
                try await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                self.isAnimating = false
                self.animationTask = nil
            } catch { }
        }
    }
    func shuffle() {
        guard !isAnimating else { return }
        do { try game.shuffle(); refreshBoard(); hintID = nil; save() }
        catch { notice = "本局的洗牌次数已用完。" }
    }
    func hint() { guard !isAnimating else { return }; hintID = game.hint() }
    func importFace(_ data: Data, kind: Int) {
        guard (0..<CardCatalog.kindCount).contains(kind), data.count <= 10 * 1024 * 1024,
            let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) == 1,
            let info = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = info[kCGImagePropertyPixelWidth] as? Int,
            let height = info[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0, Double(width) * Double(height) <= 40_000_000,
            let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 256,
                kCGImageSourceCreateThumbnailWithTransform: true
            ] as CFDictionary)
        else { notice = "请选择单帧、10 MB 以内、4000 万像素以内的图片。"; return }
        let image = UIImage(cgImage: thumbnail)
        do {
            guard let png = image.pngData() else { return }
            try png.write(to: directory.appending(path: "face-\(kind).png"), options: .atomic)
            customFaces[kind] = image.preparingForDisplay() ?? image
            faceRevision += 1
        } catch { notice = "牌面保存失败。" }
    }
    func resetFace(_ kind: Int) {
        do {
            let url = directory.appending(path: "face-\(kind).png")
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            customFaces.removeValue(forKey: kind)
            faceRevision += 1
        } catch { notice = "无法重置牌面。" }
    }
}

enum FaceTheme: String, CaseIterable, Identifiable, Sendable {
    case meadow, cosmic, picnic
    var id: String { rawValue }
    var title: String { switch self { case .meadow: "月光牧场"; case .cosmic: "宇宙漫游"; case .picnic: "午后野餐" } }
    var symbols: [String] {
        switch self {
        case .meadow: ["🐑", "🍀", "🍄", "🌼", "🥕", "🦋", "🍓", "🌱", "🌽", "🧶", "🐝", "🍎", "🌻", "🪵", "🪣", "🐞", "🌰", "🪺", "🍐", "🌵"]
        case .cosmic: ["🌙", "🪐", "🚀", "⭐️", "☄️", "🛸", "🌎", "👾", "☀️", "🛰️", "🔭", "🧑‍🚀", "💎", "🧲", "⚡️", "🧪", "🤖", "🔋", "🌀", "🧭"]
        case .picnic: ["🍒", "🥨", "🧁", "🍋", "🥑", "🍑", "🍉", "🍪", "🍇", "🧀", "🍍", "🥝", "🥐", "🍩", "🍌", "🍔", "🍕", "🍭", "🥥", "🥦"]
        }
    }
}
