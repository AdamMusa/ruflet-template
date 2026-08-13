import SwiftUI

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

struct RufletTextStyleModifier: ViewModifier {
    let style: RufletTextStyle?

    func body(content: Content) -> some View {
        content
            .font(resolvedFont)
            .fontWeight(style?.weight)
            .italic(style?.italic == true)
            .foregroundStyle(style?.color ?? .primary)
            .tracking(style?.letterSpacing ?? 0)
            .underline(
                style.map { $0.decoration & 0x1 > 0 } ?? false,
                color: style?.decorationColor
            )
            .strikethrough(
                style.map { $0.decoration & 0x4 > 0 } ?? false,
                color: style?.decorationColor
            )
            .background(style?.backgroundColor ?? .clear)
    }

    private var resolvedFont: Font? {
        guard let style else { return nil }
        let size = style.size ?? 14
        if let family = style.fontFamily {
            return .custom(family, size: size)
        }
        return .system(size: size)
    }
}
