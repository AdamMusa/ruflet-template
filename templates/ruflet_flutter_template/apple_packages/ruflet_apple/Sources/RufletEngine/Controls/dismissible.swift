import RufletProtocol
import SwiftUI

/// Apple-native port of Flet's `DismissibleControl`.
@MainActor
public struct DismissibleControl: View {
    @ObservedObject public var control: RufletControl
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var offset = CGSize.zero
    @State private var measuredSize = CGSize.zero
    @State private var previousReached = false
    @State private var pendingDirection: RufletDismissDirection?
    @State private var collapsed = false
    @State private var dismissed = false
    @State private var invokeToken: UUID?
    @State private var confirmationTimeout: Task<Void, Never>?
    @State private var dismissalTask: Task<Void, Never>?

    public init(control: RufletControl) {
        self.control = control
    }

    public var body: some View {
        if let content = control.child("content") {
            LayoutControl(control: control) {
                dismissible(content)
            }
            .onAppear(perform: installInvokeListener)
            .onDisappear(perform: dispose)
        } else {
            ErrorControl("Dismissible.content must be visible")
        }
    }

    private func dismissible(_ content: RufletControl) -> some View {
        ZStack {
            background
            if !dismissed {
                ControlWidget(control: content)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(key: RufletDismissibleSizeKey.self, value: proxy.size)
                        }
                    }
                    .offset(offset)
                    .gesture(dragGesture)
            }
        }
        .frame(
            width: collapsed && isVerticalDismissal ? 0 : nil,
            height: collapsed && !isVerticalDismissal ? 0 : nil
        )
        .clipped()
        .animation(.linear(duration: resizeDuration), value: collapsed)
        .onPreferenceChange(RufletDismissibleSizeKey.self) { measuredSize = $0 }
    }

    @ViewBuilder
    private var background: some View {
        if let background = activeBackground {
            background
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color.clear
        }
    }

    private var activeBackground: AnyView? {
        guard let direction = currentDirection else { return control.buildWidget("background") }
        switch direction {
        case .endToStart, .up:
            return control.buildWidget("secondary_background") ?? control.buildWidget("background")
        default:
            return control.buildWidget("background")
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: control.disabled || dismissDirection == .none ? .greatestFiniteMagnitude : 10)
            .onChanged { value in updateDrag(value.translation) }
            .onEnded { _ in endDrag() }
    }

    private func updateDrag(_ translation: CGSize) {
        guard pendingDirection == nil else { return }
        let allowed = allowedTranslation(translation)
        offset = allowed
        guard let direction = direction(for: allowed) else { return }
        let reached = progress(for: direction) >= threshold(for: direction)
        if control.boolean("on_update", default: false) {
            control.triggerEvent("update", data: [
                "direction": .string(direction.rawValue),
                "progress": .double(progress(for: direction)),
                "reached": .bool(reached),
                "previous_reached": .bool(previousReached),
            ])
        }
        previousReached = reached
    }

    private func endDrag() {
        guard let direction = currentDirection,
              progress(for: direction) >= threshold(for: direction) else {
            resetPosition()
            return
        }
        if control.boolean("on_confirm_dismiss", default: false) {
            pendingDirection = direction
            control.triggerEvent("confirm_dismiss", data: ["direction": .string(direction.rawValue)])
            confirmationTimeout?.cancel()
            confirmationTimeout = Task { @MainActor in
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { return }
                pendingDirection = nil
                resetPosition()
            }
        } else {
            completeDismiss(direction)
        }
    }

    private func completeDismiss(_ direction: RufletDismissDirection) {
        pendingDirection = nil
        confirmationTimeout?.cancel()
        previousReached = false
        withAnimation(.linear(duration: movementDuration)) {
            offset = finalOffset(for: direction)
        }
        dismissalTask?.cancel()
        dismissalTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(movementDuration))
            guard !Task.isCancelled else { return }
            if control.boolean("on_resize", default: false) {
                control.triggerEvent("resize")
            }
            collapsed = true
            try? await Task.sleep(for: .seconds(resizeDuration))
            guard !Task.isCancelled else { return }
            dismissed = true
            if control.boolean("on_dismiss", default: false) {
                control.triggerEvent("dismiss", data: ["direction": .string(direction.rawValue)])
            }
        }
    }

    private func resetPosition() {
        pendingDirection = nil
        previousReached = false
        withAnimation(.linear(duration: movementDuration)) { offset = .zero }
    }

    private func allowedTranslation(_ translation: CGSize) -> CGSize {
        switch dismissDirection {
        case .horizontal:
            return CGSize(width: translation.width, height: 0)
        case .vertical:
            return CGSize(width: 0, height: translation.height)
        case .startToEnd:
            let startSign: CGFloat = effectiveLayoutDirection == .rightToLeft ? -1 : 1
            return CGSize(width: translation.width * startSign > 0 ? translation.width : 0, height: 0)
        case .endToStart:
            let endSign: CGFloat = effectiveLayoutDirection == .rightToLeft ? 1 : -1
            return CGSize(width: translation.width * endSign > 0 ? translation.width : 0, height: 0)
        case .up:
            return CGSize(width: 0, height: min(translation.height, 0))
        case .down:
            return CGSize(width: 0, height: max(translation.height, 0))
        case .none:
            return .zero
        }
    }

    private func direction(for translation: CGSize) -> RufletDismissDirection? {
        switch dismissDirection {
        case .horizontal, .startToEnd, .endToStart:
            guard translation.width != 0 else { return nil }
            let physicalStartToEnd = effectiveLayoutDirection == .rightToLeft
                ? translation.width < 0
                : translation.width > 0
            return physicalStartToEnd ? .startToEnd : .endToStart
        case .vertical, .up, .down:
            guard translation.height != 0 else { return nil }
            return translation.height < 0 ? .up : .down
        case .none:
            return nil
        }
    }

    private func progress(for direction: RufletDismissDirection) -> Double {
        let extent = direction == .up || direction == .down ? measuredSize.height : measuredSize.width
        let distance = direction == .up || direction == .down ? abs(offset.height) : abs(offset.width)
        guard extent > 0 else { return 0 }
        return min(max(Double(distance / extent), 0), 1)
    }

    private func threshold(for direction: RufletDismissDirection) -> Double {
        parseDismissThresholds(control.dynamicValue("dismiss_thresholds"), [:])?[direction] ?? 0.4
    }

    private func finalOffset(for direction: RufletDismissDirection) -> CGSize {
        let crossAxis = CGFloat(control.number("cross_axis_end_offset", default: 0) ?? 0)
        switch direction {
        case .startToEnd:
            let x = effectiveLayoutDirection == .rightToLeft ? -measuredSize.width : measuredSize.width
            return CGSize(width: x, height: measuredSize.height * crossAxis)
        case .endToStart:
            let x = effectiveLayoutDirection == .rightToLeft ? measuredSize.width : -measuredSize.width
            return CGSize(width: x, height: measuredSize.height * crossAxis)
        case .up:
            return CGSize(width: measuredSize.width * crossAxis, height: -measuredSize.height)
        case .down:
            return CGSize(width: measuredSize.width * crossAxis, height: measuredSize.height)
        default:
            return .zero
        }
    }

    private func installInvokeListener() {
        guard invokeToken == nil else { return }
        invokeToken = control.addInvokeMethodListener { name, arguments in
            try await invoke(name, arguments: arguments)
        }
    }

    private func invoke(_ name: String, arguments: RufletValue) async throws -> RufletValue {
        guard name == "confirm_dismiss" else { throw RufletDismissibleError.unknownMethod(name) }
        guard let direction = pendingDirection else { return .null }
        confirmationTimeout?.cancel()
        if arguments.map?["dismiss"]?.bool == true {
            completeDismiss(direction)
        } else {
            resetPosition()
        }
        return .null
    }

    private func dispose() {
        confirmationTimeout?.cancel()
        dismissalTask?.cancel()
        if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
        invokeToken = nil
    }

    private var dismissDirection: RufletDismissDirection {
        parseDismissDirection(control.string("dismiss_direction"), .horizontal)!
    }
    private var currentDirection: RufletDismissDirection? { direction(for: offset) }
    private var effectiveLayoutDirection: LayoutDirection {
        control.boolean("rtl", default: layoutDirection == .rightToLeft) ? .rightToLeft : .leftToRight
    }
    private var movementDuration: TimeInterval { parseDuration(control.dynamicValue("duration"), 0.2)! }
    private var resizeDuration: TimeInterval { parseDuration(control.dynamicValue("duration"), 0.3)! }
    private var isVerticalDismissal: Bool {
        guard let direction = currentDirection ?? pendingDirection else {
            return dismissDirection == .vertical || dismissDirection == .up || dismissDirection == .down
        }
        return direction == .up || direction == .down
    }
}

private struct RufletDismissibleSizeKey: PreferenceKey {
    static let defaultValue = CGSize.zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private enum RufletDismissibleError: Error {
    case unknownMethod(String)
}
