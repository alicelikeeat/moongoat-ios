import SwiftUI
import MoonGoatCore
import PhotosUI

struct ContentView: View {
    @ObservedObject var model: GameModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var cards
    @Namespace private var glass
    @State private var expandedTools = true
    @State private var showStudio = false
    @State private var showNew = false
    @State private var showHelp = false
    var body: some View {
        GeometryReader { _ in
            ZStack {
                LinearGradient(colors: [Color(red: 0.08, green: 0.13, blue: 0.19), Color(red: 0.16, green: 0.13, blue: 0.25), Color(red: 0.06, green: 0.22, blue: 0.23)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                Circle().fill(.purple.opacity(0.19)).blur(radius: 65).frame(width: 230).offset(x: 140, y: -230)
                BubbleField(pausedWhileInteracting: model.isAnimating).ignoresSafeArea()
                VStack(spacing: 18) {
                    header
                    progress
                    board.frame(maxHeight: .infinity)
                    tray
                    controls
                    Text("三张相同即消除 · 七格装满则结束")
                        .font(.caption2).foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 10)
                .frame(maxWidth: 520).frame(maxWidth: .infinity)
                if model.visibleState.status != .playing { result }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.8), value: model.visibleState)
            .animation(reduceMotion ? nil : .easeInOut, value: model.hintID)
        }
        .onChange(of: reduceMotion) { _, _ in model.finishAnimations() }
        .sheet(isPresented: $showStudio) { FaceStudio(model: model).presentationDetents([.large]) }
        .sheet(isPresented: $showHelp) { help.presentationDetents([.medium]) }
        .confirmationDialog("开始新局？当前进度将替换。", isPresented: $showNew, titleVisibility: .visible) {
            Button("轻松 · 108 张 · 12 类") { model.newGame(difficulty: .relaxed) }
            Button("标准 · 240 张 · 16 类") { model.newGame(difficulty: .standard) }
            Button("挑战 · 360 张 · 20 类") { model.newGame(difficulty: .expert) }
        }
        .alert("MoonGoat", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button("知道了") { model.notice = nil }
        } message: { Text(model.notice ?? "") }
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("MOONGOAT").font(.system(size: 12, weight: .bold, design: .rounded)).tracking(4).foregroundStyle(.mint)
                Text("月下消消羊").font(.system(size: 28, weight: .bold, design: .rounded))
            }
            Spacer()
            Button { showHelp = true } label: { Image(systemName: "questionmark").frame(width: 44, height: 44).moonGlass(radius: 22) }.accessibilityLabel("玩法说明")
            Button { showStudio = true } label: { Image(systemName: "paintpalette").frame(width: 44, height: 44).moonGlass(radius: 22) }.accessibilityLabel("打开牌面工作室")
        }.foregroundStyle(.white)
    }
    private var progress: some View {
        HStack(spacing: 14) {
            Image(systemName: "moon.stars.fill").foregroundStyle(.mint).symbolEffect(.bounce, value: model.celebration)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("剩余 \(model.visibleState.board.count) 张 · \(model.visibleState.kindCount) 类").fontWeight(.medium)
                    Spacer()
                    Text("\(model.visibleState.matched) / \(model.visibleState.matched + model.visibleState.board.count + model.visibleState.tray.count)").monospacedDigit()
                }.font(.caption)
                ProgressView(value: Double(model.visibleState.matched), total: Double(model.visibleState.matched + model.visibleState.board.count + model.visibleState.tray.count)).tint(.mint)
            }
        }.padding(16).moonGlass()
    }
    private var board: some View {
        BoardView(snapshot: model.boardSnapshot, bounds: model.visibleState.boardBounds,
                  theme: model.theme, images: model.customFaces, faceRevision: model.faceRevision,
                  hintID: model.hintID, namespace: cards, animated: !reduceMotion, owner: ObjectIdentifier(model)) { id in
            model.pick(id, animated: !reduceMotion)
        }
        .equatable()
        .disabled(model.isAnimating || model.visibleState.status != .playing)
    }
    private var tray: some View {
        VStack(spacing: 12) {
            HStack {
                Text("月光收集槽").font(.caption).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("\(model.visibleState.tray.count) / 7").font(.caption.monospacedDigit()).foregroundStyle(model.visibleState.tray.count >= 5 ? .orange : .mint)
            }
            GeometryReader { proxy in
                let size = (proxy.size.width - 24) / 7
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 9).fill(.black.opacity(0.15)).frame(width: size, height: size)
                    }
                }
                NativeGlassGroup(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(Array(model.visibleState.tray.enumerated()), id: \.element.id) { index, card in
                            let merged = model.mergingIDs.contains(card.id)
                            let matchingIndices = model.visibleState.tray.indices.filter { model.mergingIDs.contains(model.visibleState.tray[$0].id) }
                            let center = matchingIndices.isEmpty ? index : matchingIndices[matchingIndices.count / 2]
                            face(card.kind)
                                .opacity(merged && index != center ? 0 : 1)
                                .frame(width: size, height: size)
                                .morphGlass(id: "tray-\(card.id)", namespace: glass, unionID: merged ? "matching-triple" : nil)
                                .matchedGeometryEffect(id: card.id, in: cards)
                                .scaleEffect(merged ? 0.9 : 1)
                                .offset(x: merged ? CGFloat(center - index) * (size + 4) : 0)
                                .zIndex(merged ? 1 : 0)
                        }
                    }
                }
            }.frame(height: 45)
        }.padding(16)
        .background(.black.opacity(0.12), in: .rect(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12)))
        .overlay { MatchBurst(trigger: model.celebration) }
        .sensoryFeedback(.success, trigger: model.celebration) { _, _ in model.haptics }
    }
    private var controls: some View {
        NativeGlassGroup(spacing: 16) {
            HStack(spacing: 8) {
                tool(expandedTools ? "收起" : "工具", icon: expandedTools ? "chevron.down" : "ellipsis", id: "expand") {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.72)) {
                        expandedTools.toggle()
                    }
                }
                tool("撤回", icon: "arrow.uturn.backward", id: "undo", disabled: !model.game.canUndo || model.isAnimating) { model.undo(animated: !reduceMotion) }
                if expandedTools {
                    tool("洗牌 \(model.visibleState.shufflesLeft)", icon: "shuffle", id: "shuffle", disabled: model.visibleState.shufflesLeft == 0 || model.visibleState.status != .playing || model.isAnimating) { model.shuffle() }
                    tool("提示", icon: "sparkles", id: "hint", disabled: model.visibleState.status != .playing || model.isAnimating) { model.hint() }
                }
                tool("新局", icon: "arrow.clockwise", id: "new") { showNew = true }
            }
        }
    }
    private func tool(_ title: String, icon: String, id: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon).font(.title3).contentTransition(.symbolEffect(.replace))
                Text(title).font(.caption2)
            }
                .frame(maxWidth: .infinity).frame(minHeight: 66)
                .morphGlass(id: "tool-" + id, namespace: glass, radius: 20)
        }.buttonStyle(.plain).foregroundStyle(disabled ? .white.opacity(0.3) : .white).disabled(disabled)
    }
    private func face(_ kind: Int, size: CGFloat = 29) -> some View {
        Group {
            if let image = model.customFaces[kind] { Image(uiImage: image).resizable().scaledToFit().padding(5) }
            else { Text(model.theme.symbols[kind]).font(.system(size: size)).minimumScaleFactor(0.5) }
        }
    }
    private var result: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 20) {
                Text(model.visibleState.status == .won ? "🌙" : "☁️").font(.system(size: 64))
                Text(model.visibleState.status == .won ? "今晚，你点亮了月亮" : "收集槽装满啦").font(.title2.bold())
                Text(model.visibleState.status == .won ? "让下一场月光，继续发生。" : "撤回一步，或换个思路重新出发。")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("再来一局") { showNew = true }.buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
                if model.game.canUndo { Button("撤回上一步") { model.undo(animated: !reduceMotion) }.buttonStyle(.bordered) }
                Button("更换牌面") { showStudio = true }.font(.caption)
            }.padding(30).moonGlass(radius: 32).padding(24)
        }
    }
    private var help: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("一小片月光，一点小策略").font(.title2.bold())
            Text("点击未被上层覆盖的牌，将它放入七格收集槽。三张同类牌会自动消除；先消除，再判定满槽。清空所有牌即可通关。下方两侧是储备牌堆，同样只能从顶层拿牌。")
            Text("提示会优先照顾槽中已有的牌，不是通关解法。初始牌局保证有解；洗牌后不保证。撤回可以恢复消除和洗牌。")
                .font(.subheadline).foregroundStyle(.secondary)
            Toggle("触感反馈", isOn: $model.haptics)
        }.padding(28)
    }
}
