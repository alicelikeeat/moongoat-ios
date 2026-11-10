import SwiftUI

struct GlassPanel: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var radius: CGFloat = 24
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(red: 0.16, green: 0.18, blue: 0.24), in: .rect(cornerRadius: radius))
        } else {
            #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                content.glassEffect(.regular, in: .rect(cornerRadius: radius))
            } else { fallback(content) }
            #else
            fallback(content)
            #endif
        }
    }
    private func fallback(_ content: Content) -> some View {
        content.background(.ultraThinMaterial, in: .rect(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(0.18)))
    }
}
extension View {
    func moonGlass(radius: CGFloat = 24) -> some View { modifier(GlassPanel(radius: radius)) }
}
struct BubbleField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var burst: Int = 0
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<18 {
                    let radius = CGFloat(10 + index % 5 * 9)
                    let x = (sin(time * 0.15 + Double(index) * 2.4) * 0.35 + 0.5) * size.width
                    let phase = (time * (8 + Double(index % 3) * 4) + Double(index) * 57).truncatingRemainder(dividingBy: size.height + 100)
                    let y = size.height + 50 - phase
                    let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                    let path = Path(ellipseIn: rect)
                    context.fill(path, with: .color(.mint.opacity(0.025)))
                    context.stroke(path, with: .color(.white.opacity(0.10)), lineWidth: 1)
                    context.fill(Path(ellipseIn: CGRect(x: x + radius * 0.4, y: y + radius * 0.3, width: radius * 0.35, height: radius * 0.18)), with: .color(.white.opacity(0.22)))
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct MatchBurst: View {
    var trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    @State private var visible = false
    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                let angle = Double(index) * .pi / 5
                Circle().stroke(.mint.opacity(0.8), lineWidth: 1.5)
                    .frame(width: CGFloat(7 + index % 3 * 3))
                    .offset(x: cos(angle) * (expanded ? 100 : 8), y: sin(angle) * (expanded ? 60 : 4))
            }
        }
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(false).accessibilityHidden(true)
        .task(id: trigger) { @MainActor in
            guard trigger > 0, !reduceMotion else { return }
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { expanded = false; visible = true }
            do {
                try await Task.sleep(for: .milliseconds(20))
                withAnimation(.easeOut(duration: 0.65)) { expanded = true; visible = false }
            } catch { visible = false }
        }
    }
}
