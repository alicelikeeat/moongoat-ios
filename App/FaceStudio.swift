import SwiftUI
import PhotosUI

struct FaceStudio: View {
    @ObservedObject var model: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PhotosPickerItem?
    @State private var selectedKind = 0
    @State private var importing = false
    var body: some View {
        let pickerTitle = importing ? "正在导入…" : "为牌面 \(selectedKind + 1) 选择照片"
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("让每张牌，都像你").font(.largeTitle.bold())
                        Text("换一套心情，或用自己的图片重绘月光。")
                            .foregroundStyle(.secondary)
                    }
                    Picker("牌面主题", selection: $model.theme) {
                        ForEach(FaceTheme.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(0..<8, id: \.self) { kind in
                            VStack(spacing: 12) {
                                Group {
                                    if let image = model.customFaces[kind] { Image(uiImage: image).resizable().scaledToFit() }
                                    else { Text(model.theme.symbols[kind]).font(.system(size: 48)) }
                                }.frame(height: 76)
                                Text("牌面 \(kind + 1)").font(.caption).foregroundStyle(.secondary)
                                Button(selectedKind == kind ? "已选中" : "选择替换") { selectedKind = kind }.buttonStyle(.bordered)
                                if model.customFaces[kind] != nil { Button("恢复默认") { model.resetFace(kind) }.font(.caption) }
                            }.frame(maxWidth: .infinity).padding(16).moonGlass()
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(selectedKind == kind ? .mint : .clear, lineWidth: 2))
                        }
                    }
                    PhotosPicker(selection: $selection, matching: .images) {
                        Label(pickerTitle, systemImage: "photo.badge.plus")
                            .frame(maxWidth: .infinity).padding(10)
                    }.buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black).disabled(importing)
                    Text("图片仅在设备内处理，不上传。支持单帧图片，最大 10 MB / 4000 万像素，保存为 256 像素缩略图。请使用有权使用的图片。自定义牌面优先于主题，不改变游戏规则。")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(22)
            }
            .background(Color(red: 0.09, green: 0.14, blue: 0.20))
            .navigationTitle("牌面工作室").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .onChange(of: selection) { _, value in
                guard let value else { return }
                let kind = selectedKind
                importing = true
                Task { @MainActor in
                    defer { importing = false; selection = nil }
                    do {
                        if let data = try await value.loadTransferable(type: Data.self) { model.importFace(data, kind: kind) }
                    } catch { model.notice = "图片读取失败，请重试。" }
                }
            }
        }.preferredColorScheme(.dark)
    }
}
