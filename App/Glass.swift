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
/// Shared native glass rendering lets nearby surfaces merge and separate.
struct NativeGlassGroup<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content
    @ViewBuilder var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            GlassEffectContainer(spacing: spacing) { content }
        } else { content }
        #else
        content
        #endif
    }
}

struct MorphGlass: ViewModifier {
    var id: String
    var namespace: Namespace.ID
    var unionID: String? = nil
    var radius: CGFloat = 12
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            if reduceMotion {
                content.glassEffect(.regular.tint(.mint.opacity(0.12)), in: .rect(cornerRadius: radius))
            } else {
                content
                    .glassEffect(.regular.tint(.mint.opacity(0.12)).interactive(), in: .rect(cornerRadius: radius))
                    .glassEffectID(id, in: namespace)
                    .glassEffectUnion(id: unionID, namespace: namespace)
                    .glassEffectTransition(.matchedGeometry)
            }
        } else { content.moonGlass(radius: radius) }
        #else
        content.moonGlass(radius: radius)
        #endif
    }
}
extension View {
    func morphGlass(id: String, namespace: Namespace.ID, unionID: String? = nil, radius: CGFloat = 12) -> some View {
        modifier(MorphGlass(id: id, namespace: namespace, unionID: unionID, radius: radius))
    }
}

private struct BubbleSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            Color.clear.glassEffect(.regular.tint(.mint.opacity(0.05)), in: .circle)
                .overlay(Circle().stroke(.white.opacity(0.12)))
        } else { fallback }
        #else
        fallback
        #endif
    }
    private var fallback: some View {
        Circle().fill(reduceTransparency ? Color(white: 0.2) : Color.white.opacity(0.035))
            .overlay(Circle().stroke(.white.opacity(0.15)))
    }
}
struct BubbleField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion || scenePhase != .active)) { timeline in
            GeometryReader { proxy in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                NativeGlassGroup(spacing: 14) {
                    ZStack {
                        ForEach(0..<9, id: \.self) { index in
                            let diameter = CGFloat(28 + index % 4 * 14)
                            let x = (sin(time * 0.12 + Double(index) * 2.4) * 0.42 + 0.5) * proxy.size.width
                            let phase = (time * (7 + Double(index % 3) * 3) + Double(index) * 87).truncatingRemainder(dividingBy: max(1, proxy.size.height + 120))
                            BubbleSurface().frame(width: diameter, height: diameter)
                                .position(x: x, y: proxy.size.height + 60 - phase)
                        }
                    }
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
