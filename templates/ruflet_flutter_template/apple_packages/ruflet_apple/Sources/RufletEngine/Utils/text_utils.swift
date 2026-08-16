import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private struct RufletInheritedTextStyleKey: EnvironmentKey {
    static let defaultValue: RufletTextStyle? = nil
}

private struct RufletInheritsTextColorKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var rufletInheritedTextStyle: RufletTextStyle? {
        get { self[RufletInheritedTextStyleKey.self] }
        set { self[RufletInheritedTextStyleKey.self] = newValue }
    }

    var rufletInheritsTextColor: Bool {
        get { self[RufletInheritsTextColorKey.self] }
        set { self[RufletInheritsTextColorKey.self] = newValue }
    }
}

public enum RufletTextAlign: String, CaseIterable, RufletStringEnum, Sendable {
    case left, right, center, justify, start, end

    var alignment: TextAlignment {
        switch self {
        case .left, .start: .leading
        case .right, .end: .trailing
        case .center: .center
        case .justify: .leading
        }
    }
}

public enum RufletTextOverflow: String, CaseIterable, RufletStringEnum, Sendable {
    case clip, fade, ellipsis, visible
}

public struct RufletTextStyle {
    public let size: Double?
    public let weight: Font.Weight?
    public let italic: Bool
    public let fontFamily: String?
    public let height: Double?
    public let decoration: Int
    public let decorationColor: Color?
    public let decorationThickness: Double?
    public let color: Color?
    public let backgroundColor: Color?
    public let letterSpacing: Double?
    public let wordSpacing: Double?
    public let overflow: RufletTextOverflow?
}

public func parseFontWeight(_ value: String?, _ defaultValue: Font.Weight? = nil) -> Font.Weight? {
    guard let value else { return defaultValue }
    return [
        "normal": .regular, "bold": .bold, "w100": .thin, "w200": .ultraLight,
        "w300": .light, "w400": .regular, "w500": .medium, "w600": .semibold,
        "w700": .bold, "w800": .heavy, "w900": .black,
    ][value.lowercased()] ?? defaultValue
}

public func parseTextStyle(_ value: Any?, _ defaultValue: RufletTextStyle? = nil) -> RufletTextStyle? {
    guard let value = rufletDictionary(value) else { return defaultValue }
    return RufletTextStyle(
        size: parseDouble(value["size"]),
        weight: parseFontWeight(value["weight"] as? String),
        italic: parseBool(value["italic"], false)!,
        fontFamily: value["font_family"] as? String,
        height: parseDouble(value["height"]),
        decoration: parseInt(value["decoration"], 0)!,
        decorationColor: parseColor(value["decoration_color"] as? String),
        decorationThickness: parseDouble(value["decoration_thickness"]),
        color: parseColor(value["color"] as? String),
        backgroundColor: parseColor(value["bgcolor"] as? String),
        letterSpacing: parseDouble(value["letter_spacing"]),
        wordSpacing: parseDouble(value["word_spacing"]),
        overflow: parseEnum(RufletTextOverflow.self, value["overflow"] as? String)
    )
}

public struct RufletTextStyleModifier: ViewModifier {
    public let style: RufletTextStyle?
    @Environment(\.rufletPageTheme) private var pageTheme
    @Environment(\.rufletInheritsTextColor) private var inheritsTextColor

    public init(style: RufletTextStyle?) {
        self.style = style
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            styled(content)
        } else {
            base(content)
        }
        #elseif os(macOS)
        styled(content)
        #endif
    }

    @ViewBuilder
    private func base(_ content: Content) -> some View {
        let styled = content
            .font(resolvedFont)
            .background(effectiveStyle?.backgroundColor ?? .clear)
            .modifier(RufletTextLineHeightModifier(style: effectiveStyle))
        if inheritsTextColor, effectiveStyle?.color == nil {
            styled
        } else {
            styled.foregroundStyle(resolvedColor)
        }
    }

    @available(iOS 16.0, *)
    private func styled(_ content: Content) -> some View {
        base(content)
            .tracking(effectiveStyle?.letterSpacing ?? 0)
            .underline(
                effectiveStyle.map { $0.decoration & 0x1 > 0 } ?? false,
                color: effectiveStyle?.decorationColor
            )
            .strikethrough(
                effectiveStyle.map { $0.decoration & 0x4 > 0 } ?? false,
                color: effectiveStyle?.decorationColor
            )
    }

    private var resolvedFont: Font? {
        guard effectiveStyle != nil || pageTheme?.fontFamily != nil else { return nil }
        let size = effectiveStyle?.size ?? 14
        var font: Font
        if let family = effectiveStyle?.fontFamily ?? pageTheme?.fontFamily {
            font = .custom(family, size: size)
        } else {
            font = .system(size: size)
        }
        if let weight = effectiveStyle?.weight { font = font.weight(weight) }
        if effectiveStyle?.italic == true { font = font.italic() }
        return font
    }

    private var resolvedColor: Color {
        effectiveStyle?.color
            ?? pageTheme?.appleContentColor ?? .primary
    }

    private var effectiveStyle: RufletTextStyle? {
        mergeTextStyles(pageTheme?.appleBodyTextStyle, style)
    }
}

private struct RufletTextLineHeightModifier: ViewModifier {
    let style: RufletTextStyle?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let size = style?.size, let multiple = style?.height {
            let target = CGFloat(size * multiple)
            content
                .lineSpacing(max(target - nativeLineHeight(size: CGFloat(size)), 0))
                .frame(minHeight: target)
        } else {
            content
        }
    }

    private func nativeLineHeight(size: CGFloat) -> CGFloat {
        #if os(iOS)
        return UIFont.systemFont(ofSize: size).lineHeight
        #elseif os(macOS)
        let font = NSFont.systemFont(ofSize: size)
        return font.ascender - font.descender + font.leading
        #endif
    }
}
