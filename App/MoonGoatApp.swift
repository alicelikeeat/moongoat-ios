import SwiftUI

@main
struct MoonGoatApp: App {
    @StateObject private var model = GameModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .preferredColorScheme(.dark)
                .onChange(of: phase) { _, value in if value != .active { model.finishAnimations(); model.saveForBackground() } }
        }
    }
}
