import RufletProtocol
import SwiftUI

@MainActor
public struct SemanticsControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        LayoutControl(control: control) {
            control.buildWidget("content")
                .accessibilityElement(children: control.boolean("exclude_semantics", default: false) ? .ignore : .contain)
                .accessibilityLabel(control.string("label") ?? "")
                .accessibilityValue(control.string("value") ?? "")
                .accessibilityHint(control.string("hint") ?? control.string("tooltip") ?? "")
                .accessibilityHidden(control.boolean("hidden", default: false))
                .accessibilityAddTraits(traits)
                .modifier(RufletPrimarySemanticsActions(control: control))
                .modifier(RufletScrollSemanticsActions(control: control))
                .modifier(RufletEditSemanticsActions(control: control))
        }
    }

    private var traits: AccessibilityTraits {
        var result: AccessibilityTraits = []
        if control.boolean("button", default: false) { result.formUnion(.isButton) }
        if control.boolean("link", default: false) { result.formUnion(.isLink) }
        if control.boolean("image", default: false) { result.formUnion(.isImage) }
        if control.boolean("header", default: false) { result.formUnion(.isHeader) }
        if control.boolean("selected", default: false) { result.formUnion(.isSelected) }
        if control.boolean("text_field", default: false) { result.formUnion(.isKeyboardKey) }
        return result
    }

    private func trigger(_ name: String) {
        if control.hasEventHandler(name) { control.triggerEvent(name) }
    }
}

@MainActor
private struct RufletPrimarySemanticsActions: ViewModifier {
    @ObservedObject var control: RufletControl

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: Text(control.string("on_tap_hint") ?? "Activate")) { trigger("click") }
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: trigger("increase")
                case .decrement: trigger("decrease")
                @unknown default: break
                }
            }
            .accessibilityAction(named: Text(control.string("on_long_press_hint") ?? "Long press")) { trigger("dismiss") }
    }

    private func trigger(_ name: String) {
        if control.hasEventHandler(name) { control.triggerEvent(name, data: .null) }
    }
}

@MainActor
private struct RufletScrollSemanticsActions: ViewModifier {
    @ObservedObject var control: RufletControl

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: Text("Scroll left")) { trigger("scroll_left") }
            .accessibilityAction(named: Text("Scroll right")) { trigger("scroll_right") }
            .accessibilityAction(named: Text("Scroll up")) { trigger("scroll_up") }
            .accessibilityAction(named: Text("Scroll down")) { trigger("scroll_down") }
    }

    private func trigger(_ name: String) {
        if control.hasEventHandler(name) { control.triggerEvent(name, data: .null) }
    }
}

@MainActor
private struct RufletEditSemanticsActions: ViewModifier {
    @ObservedObject var control: RufletControl

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: Text("Copy")) { trigger("copy") }
            .accessibilityAction(named: Text("Cut")) { trigger("cut") }
            .accessibilityAction(named: Text("Paste")) { trigger("paste") }
    }

    private func trigger(_ name: String) {
        if control.hasEventHandler(name) { control.triggerEvent(name, data: .null) }
    }
}
