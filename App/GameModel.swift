import SwiftUI
import MoonGoatCore
import ImageIO

@MainActor final class GameModel: ObservableObject {
    @Published private(set) var game: Game
    @Published var theme: FaceTheme = .meadow { didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") } }
    @Published var customFaces: [Int: UIImage] = [:]
    @Published var notice: String?
    @Published var hintID: Int?
    @Published var celebration = 0
    @Published var haptics = true
    private var savesBlocked = false
    private let directory: URL
    private let saveURL: URL

    init() {
        directory = URL.documentsDirectory.appending(path: "MoonGoat", directoryHint: .isDirectory)
        saveURL = directory.appending(path: "session.json")
        game = Game(seed: UInt64.random(in: 1...UInt64.max))
        theme = FaceTheme(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "") ?? .meadow
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: saveURL.path) {
                let envelope = try JSONDecoder().decode(Session.self, from: Data(contentsOf: saveURL))
                guard envelope.version == 1 else { throw GameError.invalidSave }
                game = try Game(restoring: envelope.game)
            }
            for kind in 0..<8 {
                let url = directory.appending(path: "face-\(kind).png")
                if let image = UIImage(contentsOfFile: url.path) { customFaces[kind] = image }
            }
        } catch {
            savesBlocked = true
            notice = "存档未能读取，已保留原文件。开始新局后才会重新保存。"
        }
    }
    struct Session: Codable { let version: Int; let game: GameState }
    func save() {
        guard !savesBlocked else { return }
        do {
            let data = try JSONEncoder().encode(Session(version: 1, game: game.state))
            try data.write(to: saveURL, options: .atomic)
        } catch { notice = "保存失败：\(error.localizedDescription)" }
    }
    func newGame(rows: Int = 4) {
        if savesBlocked, FileManager.default.fileExists(atPath: saveURL.path) {
            do {
                try FileManager.default.copyItem(at: saveURL, to: directory.appending(path: "unreadable-\(UUID().uuidString).json"))
            } catch { notice = "无法备份旧存档，未开始新局。"; return }
        }
        savesBlocked = false
        game = Game(seed: UInt64.random(in: 1...UInt64.max), rows: rows)
        hintID = nil
        save()
    }
    func pick(_ id: Int) {
        do {
            let count = try game.pick(id)
            hintID = nil
            if haptics { UIImpactFeedbackGenerator(style: count > 0 ? .medium : .light).impactOccurred() }
            if count > 0 { celebration += 1 }
            save()
        } catch { if haptics { UINotificationFeedbackGenerator().notificationOccurred(.warning) } }
    }
    func undo() { game.undo(); hintID = nil; save() }
    func shuffle() {
        do { try game.shuffle(); hintID = nil; save() }
        catch { notice = "本局的洗牌次数已用完。" }
    }
    func hint() { hintID = game.hint() }
    func importFace(_ data: Data, kind: Int) {
        guard (0..<8).contains(kind), data.count <= 10 * 1024 * 1024,
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
            customFaces[kind] = image
        } catch { notice = "牌面保存失败。" }
    }
    func resetFace(_ kind: Int) {
        do {
            let url = directory.appending(path: "face-\(kind).png")
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            customFaces.removeValue(forKey: kind)
        } catch { notice = "无法重置牌面。" }
    }
}

enum FaceTheme: String, CaseIterable, Identifiable {
    case meadow, cosmic, picnic
    var id: String { rawValue }
    var title: String { switch self { case .meadow: "月光牧场"; case .cosmic: "宇宙漫游"; case .picnic: "午后野餐" } }
    var symbols: [String] {
        switch self {
        case .meadow: ["🐑", "🍀", "🍄", "🌼", "🥕", "🦋", "🍓", "🌱"]
        case .cosmic: ["🌙", "🪐", "🚀", "⭐️", "☄️", "🛸", "🌎", "👾"]
        case .picnic: ["🍒", "🥨", "🧁", "🍋", "🥑", "🍑", "🍉", "🍪"]
        }
    }
}
