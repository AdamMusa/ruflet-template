import RufletProtocol
import SwiftUI

/// Apple-native port of Flet's `PageViewControl`.
@MainActor
public struct PageViewControl: View {
    @ObservedObject public var control: RufletControl
    @State private var selectedIndex: Int
    @State private var continuousPage: Double
    @State private var measuredPageLength: CGFloat = 1
    @State private var invokeToken: UUID?
    @GestureState private var dragTranslation: CGFloat = 0

    public init(control: RufletControl) {
        self.control = control
        let index = control.integer("selected_index", default: 0) ?? 0
        _selectedIndex = State(initialValue: index)
        _continuousPage = State(initialValue: Double(index))
    }

    public var body: some View {
        LayoutControl(control: control) {
            GeometryReader { proxy in
                pages(in: proxy.size)
            }
        }
        .onAppear(perform: installInvokeListener)
        .onDisappear(perform: removeInvokeListener)
        .onChange(of: control.integer("selected_index", default: 0) ?? 0) { index in
            selectedIndex = bounded(index)
            continuousPage = Double(selectedIndex)
        }
    }

    private func pages(in size: CGSize) -> some View {
        let availableLength = horizontal ? size.width : size.height
        let pageLength = max(availableLength * viewportFraction, 1)
        let leadingInset = padEnds ? (availableLength - pageLength) / 2 : 0
        let direction: CGFloat = reverse ? -1 : 1

        return ZStack(alignment: horizontal ? .leading : .top) {
            ForEach(Array(control.children("controls").enumerated()), id: \.element.id) { index, child in
                ControlWidget(control: child)
                    .frame(
                        width: horizontal ? pageLength : size.width,
                        height: horizontal ? size.height : pageLength
                    )
                    .offset(
                        x: horizontal
                            ? (CGFloat(index) - continuousPage) * pageLength * direction + dragTranslation + leadingInset
                            : 0,
                        y: horizontal
                            ? 0
                            : (CGFloat(index) - continuousPage) * pageLength * direction + dragTranslation + leadingInset
                    )
            }
        }
        .contentShape(Rectangle())
        .gesture(dragGesture(pageLength: pageLength, direction: direction))
        .modifier(RufletPageViewClipModifier(behavior: clipBehavior))
        .onAppear { measuredPageLength = pageLength }
        .onChange(of: pageLength) { measuredPageLength = $0 }
    }

    private func dragGesture(pageLength: CGFloat, direction: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: control.disabled ? .greatestFiniteMagnitude : 10)
            .updating($dragTranslation) { value, state, _ in
                state = horizontal ? value.translation.width : value.translation.height
            }
            .onEnded { value in
                let translation = horizontal ? value.translation.width : value.translation.height
                let predicted = horizontal ? value.predictedEndTranslation.width : value.predictedEndTranslation.height
                if snap {
                    let page = Double(selectedIndex) - Double(predicted * direction / pageLength)
                    changePage(to: Int(page.rounded()), animated: true, notify: true)
                } else {
                    let page = continuousPage - Double(translation * direction / pageLength)
                    continuousPage = min(max(page, 0), Double(max(control.children("controls").count - 1, 0)))
                    changePage(to: Int(continuousPage.rounded()), animated: false, notify: true, preserveOffset: true)
                }
            }
    }

    private func changePage(
        to requestedIndex: Int,
        animated: Bool,
        notify: Bool,
        preserveOffset: Bool = false,
        animation: Animation? = nil
    ) {
        let index = bounded(requestedIndex)
        let update = {
            selectedIndex = index
            if !preserveOffset { continuousPage = Double(index) }
        }
        if animated {
            withAnimation(animation ?? defaultAnimation) { update() }
        } else {
            update()
        }
        guard notify else { return }
        control.updateProperties(["selected_index": .int(Int64(index))])
        control.triggerEvent("change", data: .int(Int64(index)))
    }

    private func bounded(_ index: Int) -> Int {
        min(max(index, 0), max(control.children("controls").count - 1, 0))
    }

    private func installInvokeListener() {
        guard invokeToken == nil else { return }
        invokeToken = control.addInvokeMethodListener { name, arguments in
            try await invoke(name, arguments: arguments)
        }
    }

    private func removeInvokeListener() {
        guard let invokeToken else { return }
        control.removeInvokeMethodListener(invokeToken)
        self.invokeToken = nil
    }

    private func invoke(_ name: String, arguments: RufletValue) async throws -> RufletValue {
        let values = arguments.map ?? [:]
        let duration = parseDuration(
            values["duration"].map(rufletAny),
            parseDuration(control.dynamicValue("animation_duration"), 1)
        )!
        let curve = parseCurve(
            values["curve"]?.text,
            parseCurve(control.string("animation_curve"), .linear)
        )!
        let animation = curve.animation(duration: duration)

        switch name {
        case "go_to_page":
            if let index = values["index"]?.integer {
                changePage(to: index, animated: true, notify: true, animation: animation)
            }
        case "jump_to_page":
            if let index = values["index"]?.integer {
                changePage(to: index, animated: false, notify: true)
            }
        case "jump_to":
            if let offset = values["value"]?.number {
                continuousPage = min(max(offset / Double(measuredPageLength), 0), Double(max(control.children("controls").count - 1, 0)))
                changePage(to: Int(continuousPage.rounded()), animated: false, notify: true, preserveOffset: true)
            }
        case "next_page":
            changePage(to: selectedIndex + 1, animated: true, notify: true, animation: animation)
        case "previous_page":
            changePage(to: selectedIndex - 1, animated: true, notify: true, animation: animation)
        default:
            throw RufletPageViewError.unknownMethod(name)
        }
        return .null
    }

    private var defaultAnimation: Animation {
        let duration = parseDuration(control.dynamicValue("animation_duration"), 1)!
        return parseCurve(control.string("animation_curve"), .linear)!.animation(duration: duration)
    }

    private var horizontal: Bool { control.boolean("horizontal", default: true) }
    private var reverse: Bool { control.boolean("reverse", default: false) }
    private var padEnds: Bool { control.boolean("pad_ends", default: true) }
    private var snap: Bool { control.boolean("snap", default: true) }
    private var viewportFraction: CGFloat {
        let value = CGFloat(control.number("viewport_fraction", default: 1) ?? 1)
        precondition(value > 0, "PageView.viewport_fraction must be greater than zero")
        return value
    }
    private var clipBehavior: String { control.string("clip_behavior", default: "hardEdge")!.lowercased() }
}

private enum RufletPageViewError: Error {
    case unknownMethod(String)
}

private struct RufletPageViewClipModifier: ViewModifier {
    let behavior: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if behavior == "none" {
            content
        } else {
            content.clipped(antialiased: behavior == "antialias" || behavior == "antialiaswithsavelayer")
        }
    }
}
