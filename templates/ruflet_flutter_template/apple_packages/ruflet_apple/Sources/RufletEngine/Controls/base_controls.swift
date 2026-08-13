import RufletProtocol
import SwiftUI

@MainActor
struct BaseControl<Content: View>: View {
    @ObservedObject var control: RufletControl
    let child: Content

    init(control: RufletControl, @ViewBuilder child: () -> Content) {
        self.control = control
        self.child = child()
    }

    init(control: RufletControl, child: Content) {
        self.control = control
        self.child = child
    }

    var body: some View {
        child
            .modifier(RufletBaseControlModifier(control: control))
    }
}

@MainActor
struct LayoutControl<Content: View>: View {
    @ObservedObject var control: RufletControl
    let child: Content

    init(control: RufletControl, @ViewBuilder child: () -> Content) {
        self.control = control
        self.child = child()
    }

    init(control: RufletControl, child: Content) {
        self.control = control
        self.child = child
    }

    var body: some View {
        child
            .modifier(RufletLayoutControlModifier(control: control))
            .modifier(RufletBaseControlModifier(control: control))
    }
}

@MainActor
private struct RufletBaseControlModifier: ViewModifier {
    @ObservedObject var control: RufletControl

    func body(content: Content) -> some View {
        content
            .opacity(control.number("opacity") ?? 1)
            .animation(
                parseAnimation(control.dynamicValue("animate_opacity"))?.animation,
                value: control.number("opacity") ?? 1
            )
            .modifier(RufletTooltipModifier(text: control.skipsProperty("tooltip") ? nil : control.string("tooltip")))
            .environment(\.layoutDirection, control.boolean("rtl", default: false) ? .rightToLeft : .leftToRight)
            .modifier(RufletOpacityCompletionModifier(control: control))
    }
}

@MainActor
private struct RufletLayoutControlModifier: ViewModifier {
    @ObservedObject var control: RufletControl

    func body(content: Content) -> some View {
        let rotation = parseRotationDetails(control.dynamicValue("rotate"))
        let scale = parseScale(control.dynamicValue("scale"))
        let offset = parseOffset(control.dynamicValue("offset")) ?? .zero
        let alignment = parseAlignment(control.dynamicValue("align"))
        let margin = control.skipsProperty("margin") ? nil : parseMargin(control.dynamicValue("margin"))
        let width = control.skipsProperty("width") ? nil : control.number("width").map { CGFloat($0) }
        let height = control.skipsProperty("height") ? nil : control.number("height").map { CGFloat($0) }

        content
            .frame(width: width, height: height)
            .animation(parseAnimation(control.dynamicValue("animate_size"))?.animation, value: width)
            .rotationEffect(
                .radians(rotation?.angle ?? 0),
                anchor: rotation?.alignment.unitPoint ?? .center
            )
            .animation(parseAnimation(control.dynamicValue("animate_rotation"))?.animation, value: rotation?.angle ?? 0)
            .scaleEffect(
                x: scale?.scaleX ?? scale?.scale ?? 1,
                y: scale?.scaleY ?? scale?.scale ?? 1,
                anchor: scale?.alignment.unitPoint ?? .center
            )
            .animation(parseAnimation(control.dynamicValue("animate_scale"))?.animation, value: scale?.scale ?? 1)
            .modifier(RufletFractionalOffsetModifier(offset: offset))
            .animation(parseAnimation(control.dynamicValue("animate_offset"))?.animation, value: offset)
            .aspectRatio(control.number("aspect_ratio").map { CGFloat($0) }, contentMode: .fit)
            .modifier(RufletAlignmentModifier(alignment: alignment))
            .animation(parseAnimation(control.dynamicValue("animate_align"))?.animation, value: alignment)
            .padding(margin ?? EdgeInsets())
            .animation(parseAnimation(control.dynamicValue("animate_margin"))?.animation, value: margin?.top ?? 0)
            .modifier(RufletBadgeModifier(control: control))
            .modifier(RufletSizeChangeModifier(control: control))
            .modifier(RufletLayoutAnimationCompletionModifier(control: control))
    }
}

private struct RufletTooltipModifier: ViewModifier {
    let text: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let text {
            #if os(macOS)
            content.help(text)
            #elseif os(iOS)
            content.accessibilityHint(Text(text))
            #endif
        } else {
            content
        }
    }
}

private struct RufletFractionalOffsetModifier: ViewModifier {
    let offset: CGSize

    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { proxy in
                Color.clear.preference(key: RufletControlSizeKey.self, value: proxy.size)
            }
            .allowsHitTesting(false)
        }
        .modifier(RufletMeasuredOffset(offset: offset))
    }
}

private struct RufletMeasuredOffset: ViewModifier {
    let offset: CGSize
    @State private var size: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(RufletControlSizeKey.self) { size = $0 }
            .offset(x: size.width * offset.width, y: size.height * offset.height)
    }
}

private struct RufletAlignmentModifier: ViewModifier {
    let alignment: RufletAlignment?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let alignment {
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.swiftUI)
        } else {
            content
        }
    }
}

@MainActor
private struct RufletBadgeModifier: ViewModifier {
    @ObservedObject var control: RufletControl

    @ViewBuilder
    func body(content: Content) -> some View {
        if !control.skipsProperty("badge"), let badge = control.child("badge", visibleOnly: false) {
            content.overlay(alignment: parseAlignment(badge.dynamicValue("alignment"), RufletAlignment(x: 1, y: -1))!.swiftUI) {
                if badge.boolean("label_visible", default: true) {
                    if let label = badge.buildTextOrWidget("label") {
                        label
                            .foregroundStyle(parseColor(badge.string("text_color")) ?? .white)
                            .padding(parsePadding(badge.dynamicValue("padding")) ?? EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                            .background(parseColor(badge.string("bgcolor")) ?? .red, in: Capsule())
                            .offset(
                                x: parseOffset(badge.dynamicValue("offset"))?.width ?? 0,
                                y: parseOffset(badge.dynamicValue("offset"))?.height ?? 0
                            )
                    }
                }
            }
        } else if !control.skipsProperty("badge"), let badge = control.string("badge") {
            content.overlay(alignment: .topTrailing) {
                Text(badge)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.red, in: Capsule())
            }
        } else {
            content
        }
    }
}

@MainActor
private struct RufletSizeChangeModifier: ViewModifier {
    @ObservedObject var control: RufletControl
    @State private var lastSize: CGSize?
    @State private var pendingTask: Task<Void, Never>?
    @State private var lastDispatch = ProcessInfo.processInfo.systemUptime

    func body(content: Content) -> some View {
        content
            .background {
                if control.boolean("on_size_change", default: false) {
                    GeometryReader { proxy in
                        Color.clear.preference(key: RufletReportedSizeKey.self, value: proxy.size)
                    }
                }
            }
            .onPreferenceChange(RufletReportedSizeKey.self, perform: sizeChanged)
            .onDisappear { pendingTask?.cancel() }
    }

    private func sizeChanged(_ size: CGSize) {
        guard control.boolean("on_size_change", default: false), lastSize != size else { return }
        let interval = Double(control.integer("size_change_interval", default: 10) ?? 10) / 1_000
        let elapsed = ProcessInfo.processInfo.systemUptime - lastDispatch
        pendingTask?.cancel()
        if lastSize != nil, elapsed < interval {
            pendingTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: rufletSleepNanoseconds(interval - elapsed))
                guard !Task.isCancelled else { return }
                dispatch(size)
            }
        } else {
            dispatch(size)
        }
    }

    private func dispatch(_ size: CGSize) {
        lastSize = size
        lastDispatch = ProcessInfo.processInfo.systemUptime
        control.triggerEvent("size_change", data: ["w": .double(size.width), "h": .double(size.height)])
    }
}

private struct RufletControlSizeKey: PreferenceKey {
    static let defaultValue = CGSize.zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private struct RufletReportedSizeKey: PreferenceKey {
    static let defaultValue = CGSize.zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

@MainActor
private struct RufletOpacityCompletionModifier: ViewModifier {
    @ObservedObject var control: RufletControl
    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onChange(of: control.number("opacity") ?? 1) { _ in schedule("opacity", property: "animate_opacity") }
            .onDisappear { task?.cancel() }
    }

    private func schedule(_ name: String, property: String) {
        guard control.boolean("on_animation_end", default: false),
              let animation = parseAnimation(control.dynamicValue(property)) else { return }
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: rufletSleepNanoseconds(animation.duration))
            guard !Task.isCancelled else { return }
            control.triggerEvent("animation_end", data: .string(name))
        }
    }
}

@MainActor
private struct RufletLayoutAnimationCompletionModifier: ViewModifier {
    @ObservedObject var control: RufletControl
    @State private var tasks: [String: Task<Void, Never>] = [:]

    func body(content: Content) -> some View {
        content
            .onChange(of: control.dynamicValue("rotate").map(String.init(describing:)) ?? "") { _ in schedule("rotation", "animate_rotation") }
            .onChange(of: control.dynamicValue("scale").map(String.init(describing:)) ?? "") { _ in schedule("scale", "animate_scale") }
            .onChange(of: control.dynamicValue("offset").map(String.init(describing:)) ?? "") { _ in schedule("offset", "animate_offset") }
            .onChange(of: control.dynamicValue("align").map(String.init(describing:)) ?? "") { _ in schedule("align", "animate_align") }
            .onChange(of: control.dynamicValue("margin").map(String.init(describing:)) ?? "") { _ in schedule("margin", "animate_margin") }
            .onDisappear {
                tasks.values.forEach { $0.cancel() }
                tasks.removeAll()
            }
    }

    private func schedule(_ name: String, _ property: String) {
        guard control.boolean("on_animation_end", default: false),
              let animation = parseAnimation(control.dynamicValue(property)) else { return }
        tasks[name]?.cancel()
        tasks[name] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: rufletSleepNanoseconds(animation.duration))
            guard !Task.isCancelled else { return }
            control.triggerEvent("animation_end", data: .string(name))
        }
    }
}
