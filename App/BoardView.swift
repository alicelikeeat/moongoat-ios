import SwiftUI
import MoonGoatCore

/// Presentation-only view: merging/celebration publications do not rebuild the
/// board when its geometry and face inputs are unchanged.
struct BoardView: View, Equatable {
    let snapshot: BoardSnapshot
    let bounds: BoardBounds
    let theme: FaceTheme
    let images: [Int: UIImage]
    let faceRevision: Int
    let hintID: Int?
    let namespace: Namespace.ID
    let animated: Bool
    let owner: ObjectIdentifier
    let onPick: (Int) -> Void
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.snapshot == rhs.snapshot && lhs.bounds == rhs.bounds && lhs.theme == rhs.theme
            && lhs.faceRevision == rhs.faceRevision && lhs.hintID == rhs.hintID
            && lhs.namespace == rhs.namespace && lhs.animated == rhs.animated && lhs.owner == rhs.owner
    }
    var body: some View {
        GeometryReader { proxy in
            let unit = min((proxy.size.width - 8) / bounds.width, (proxy.size.height - 8) / bounds.height)
            let offsetX = (proxy.size.width - unit * bounds.width) / 2
            let offsetY = (proxy.size.height - unit * bounds.height) / 2
            let symbols = theme.symbols
            ZStack(alignment: .topLeading) {
                Color.clear
                ForEach(snapshot.cards) { card in
                    BoardTile(card: card, available: snapshot.availableIDs.contains(card.id),
                        highlighted: hintID == card.id, unit: unit, namespace: namespace,
                        symbol: symbols[card.kind], image: images[card.kind],
                        faceRevision: faceRevision, animated: animated, owner: owner, onPick: onPick)
                        .equatable()
                        .position(x: offsetX + (card.x + 0.48) * unit, y: offsetY + (card.y + 0.48) * unit)
                        .zIndex(Double(card.layer))
                }
            }
        }
    }
}
private struct BoardTile: View, Equatable {
    let card: Card
    let available: Bool
    let highlighted: Bool
    let unit: CGFloat
    let namespace: Namespace.ID
    let symbol: String
    let image: UIImage?
    let faceRevision: Int
    let animated: Bool
    let owner: ObjectIdentifier
    let onPick: (Int) -> Void
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.card == rhs.card && lhs.available == rhs.available && lhs.highlighted == rhs.highlighted
            && lhs.unit == rhs.unit && lhs.namespace == rhs.namespace && lhs.symbol == rhs.symbol
            && lhs.faceRevision == rhs.faceRevision && lhs.animated == rhs.animated && lhs.owner == rhs.owner
    }
    var body: some View {
        Button { onPick(card.id) } label: {
            Group {
                if let image { Image(uiImage: image).resizable().scaledToFit().padding(5) }
                else { Text(symbol).font(.system(size: max(16, unit * 0.56))).minimumScaleFactor(0.5) }
            }
            .opacity(available ? 1 : 0.55)
            .frame(width: unit * 0.96, height: unit * 0.96)
            // Opaque surfaces make exact-footprint culling conservative and safe.
            .background(available ? Color(red: 0.9, green: 0.95, blue: 0.88) : Color(red: 0.38, green: 0.45, blue: 0.45), in: .rect(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(highlighted ? .mint : .white.opacity(available ? 0.6 : 0.1), lineWidth: highlighted ? 3 : 1))
            .background(RoundedRectangle(cornerRadius: 13).fill(Color(red: 0.29, green: 0.39, blue: 0.32)).offset(y: 3))
        }
        .buttonStyle(.plain).disabled(!available)
        .modifier(FlightGeometry(active: available, id: card.id, namespace: namespace))
        .accessibilityLabel("\(symbol)牌，\(available ? "可选择" : "被覆盖")")
    }
}
private struct FlightGeometry: ViewModifier {
    let active: Bool
    let id: Int
    let namespace: Namespace.ID
    @ViewBuilder func body(content: Content) -> some View {
        if active { content.matchedGeometryEffect(id: id, in: namespace) }
        else { content }
    }
}
