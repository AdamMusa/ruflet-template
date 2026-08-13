import RufletProtocol
import SwiftUI

@MainActor
public struct TextControl: View {
    @ObservedObject public var control: RufletControl

    public init(control: RufletControl) {
        self.control = control
    }

    public var body: some View {
        LayoutControl(control: control) {
            text
                .modifier(RufletTextStyleModifier(style: resolvedStyle))
                .multilineTextAlignment(textAlignment)
                .lineLimit(control.integer("max_lines"))
                .fixedSize(horizontal: control.boolean("no_wrap", default: false), vertical: false)
                .truncationMode(.tail)
                .accessibilityLabel(control.string("semantics_label") ?? control.string("value", default: "")!)
                .modifier(RufletTextSelectionModifier(enabled: control.boolean("selectable", default: false)))
                .onTapGesture {
                    if control.hasEventHandler("tap") {
                        control.triggerEvent("tap")
                    }
                }
        }
    }

    private var text: Text {
        control.children("spans").reduce(Text(control.string("value", default: "")!)) { partial, span in
            span.notifyParent = true
            return partial + inlineText(span)
        }
    }

    private func inlineText(_ span: RufletControl) -> Text {
        var result = Text(span.string("text", default: "")!)
        let style = parseTextStyle(span.dynamicValue("style"))
        if let size = style?.size { result = result.font(.system(size: size)) }
        if let weight = style?.weight { result = result.fontWeight(weight) }
        if style?.italic == true { result = result.italic() }
        if let color = style?.color { result = result.foregroundColor(color) }
        for child in span.children("spans") {
            result = result + inlineText(child)
        }
        return result
    }

    private var resolvedStyle: RufletTextStyle? {
        let style = parseTextStyle(control.dynamicValue("style"))
        return RufletTextStyle(
            size: control.number("size") ?? style?.size,
            weight: parseFontWeight(control.string("weight")) ?? style?.weight,
            italic: control.boolean("italic", default: style?.italic ?? false),
            fontFamily: control.string("font_family") ?? style?.fontFamily,
            height: style?.height,
            decoration: style?.decoration ?? 0,
            decorationColor: style?.decorationColor,
            decorationThickness: style?.decorationThickness,
            color: parseColor(control.string("color")) ?? style?.color,
            backgroundColor: parseColor(control.string("bgcolor")) ?? style?.backgroundColor,
            letterSpacing: style?.letterSpacing,
            wordSpacing: style?.wordSpacing,
            overflow: parseEnum(RufletTextOverflow.self, control.string("overflow")) ?? style?.overflow
        )
    }

    private var textAlignment: TextAlignment {
        parseEnum(RufletTextAlign.self, control.string("text_align"), .start)!.alignment
    }
}

private struct RufletTextSelectionModifier: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.textSelection(.enabled)
        } else {
            content.textSelection(.disabled)
        }
    }
}
