import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private let materialColors: [String: UInt32] = [
    "red50": 0xffffebee, "red100": 0xffffcdd2, "red200": 0xffef9a9a,
    "red300": 0xffe57373, "red400": 0xffef5350, "red500": 0xfff44336,
    "red600": 0xffe53935, "red700": 0xffd32f2f, "red800": 0xffc62828,
    "red900": 0xffb71c1c, "redaccent100": 0xffff8a80, "redaccent200": 0xffff5252,
    "redaccent400": 0xffff1744, "redaccent700": 0xffd50000,
    "pink50": 0xfffce4ec, "pink100": 0xfff8bbd0, "pink200": 0xfff48fb1,
    "pink300": 0xfff06292, "pink400": 0xffec407a, "pink500": 0xffe91e63,
    "pink600": 0xffd81b60, "pink700": 0xffc2185b, "pink800": 0xffad1457,
    "pink900": 0xff880e4f, "pinkaccent100": 0xffff80ab, "pinkaccent200": 0xffff4081,
    "pinkaccent400": 0xfff50057, "pinkaccent700": 0xffc51162,
    "purple50": 0xfff3e5f5, "purple100": 0xffe1bee7, "purple200": 0xffce93d8,
    "purple300": 0xffba68c8, "purple400": 0xffab47bc, "purple500": 0xff9c27b0,
    "purple600": 0xff8e24aa, "purple700": 0xff7b1fa2, "purple800": 0xff6a1b9a,
    "purple900": 0xff4a148c, "purpleaccent100": 0xffea80fc, "purpleaccent200": 0xffe040fb,
    "purpleaccent400": 0xffd500f9, "purpleaccent700": 0xffaa00ff,
    "deeppurple50": 0xffede7f6, "deeppurple100": 0xffd1c4e9, "deeppurple200": 0xffb39ddb,
    "deeppurple300": 0xff9575cd, "deeppurple400": 0xff7e57c2, "deeppurple500": 0xff673ab7,
    "deeppurple600": 0xff5e35b1, "deeppurple700": 0xff512da8, "deeppurple800": 0xff4527a0,
    "deeppurple900": 0xff311b92, "deeppurpleaccent100": 0xffb388ff,
    "deeppurpleaccent200": 0xff7c4dff, "deeppurpleaccent400": 0xff651fff,
    "deeppurpleaccent700": 0xff6200ea,
    "indigo50": 0xffe8eaf6, "indigo100": 0xffc5cae9, "indigo200": 0xff9fa8da,
    "indigo300": 0xff7986cb, "indigo400": 0xff5c6bc0, "indigo500": 0xff3f51b5,
    "indigo600": 0xff3949ab, "indigo700": 0xff303f9f, "indigo800": 0xff283593,
    "indigo900": 0xff1a237e, "indigoaccent100": 0xff8c9eff, "indigoaccent200": 0xff536dfe,
    "indigoaccent400": 0xff3d5afe, "indigoaccent700": 0xff304ffe,
    "blue50": 0xffe3f2fd, "blue100": 0xffbbdefb, "blue200": 0xff90caf9,
    "blue300": 0xff64b5f6, "blue400": 0xff42a5f5, "blue500": 0xff2196f3,
    "blue600": 0xff1e88e5, "blue700": 0xff1976d2, "blue800": 0xff1565c0,
    "blue900": 0xff0d47a1, "blueaccent100": 0xff82b1ff, "blueaccent200": 0xff448aff,
    "blueaccent400": 0xff2979ff, "blueaccent700": 0xff2962ff,
    "lightblue50": 0xffe1f5fe, "lightblue100": 0xffb3e5fc, "lightblue200": 0xff81d4fa,
    "lightblue300": 0xff4fc3f7, "lightblue400": 0xff29b6f6, "lightblue500": 0xff03a9f4,
    "lightblue600": 0xff039be5, "lightblue700": 0xff0288d1, "lightblue800": 0xff0277bd,
    "lightblue900": 0xff01579b, "lightblueaccent100": 0xff80d8ff,
    "lightblueaccent200": 0xff40c4ff, "lightblueaccent400": 0xff00b0ff,
    "lightblueaccent700": 0xff0091ea,
    "cyan50": 0xffe0f7fa, "cyan100": 0xffb2ebf2, "cyan200": 0xff80deea,
    "cyan300": 0xff4dd0e1, "cyan400": 0xff26c6da, "cyan500": 0xff00bcd4,
    "cyan600": 0xff00acc1, "cyan700": 0xff0097a7, "cyan800": 0xff00838f,
    "cyan900": 0xff006064, "cyanaccent100": 0xff84ffff, "cyanaccent200": 0xff18ffff,
    "cyanaccent400": 0xff00e5ff, "cyanaccent700": 0xff00b8d4,
    "teal50": 0xffe0f2f1, "teal100": 0xffb2dfdb, "teal200": 0xff80cbc4,
    "teal300": 0xff4db6ac, "teal400": 0xff26a69a, "teal500": 0xff009688,
    "teal600": 0xff00897b, "teal700": 0xff00796b, "teal800": 0xff00695c,
    "teal900": 0xff004d40, "tealaccent100": 0xffa7ffeb, "tealaccent200": 0xff64ffda,
    "tealaccent400": 0xff1de9b6, "tealaccent700": 0xff00bfa5,
    "green50": 0xffe8f5e9, "green100": 0xffc8e6c9, "green200": 0xffa5d6a7,
    "green300": 0xff81c784, "green400": 0xff66bb6a, "green500": 0xff4caf50,
    "green600": 0xff43a047, "green700": 0xff388e3c, "green800": 0xff2e7d32,
    "green900": 0xff1b5e20, "greenaccent100": 0xffb9f6ca, "greenaccent200": 0xff69f0ae,
    "greenaccent400": 0xff00e676, "greenaccent700": 0xff00c853,
    "lightgreen50": 0xfff1f8e9, "lightgreen100": 0xffdcedc8, "lightgreen200": 0xffc5e1a5,
    "lightgreen300": 0xffaed581, "lightgreen400": 0xff9ccc65, "lightgreen500": 0xff8bc34a,
    "lightgreen600": 0xff7cb342, "lightgreen700": 0xff689f38, "lightgreen800": 0xff558b2f,
    "lightgreen900": 0xff33691e, "lightgreenaccent100": 0xffccff90,
    "lightgreenaccent200": 0xffb2ff59, "lightgreenaccent400": 0xff76ff03,
    "lightgreenaccent700": 0xff64dd17,
    "lime50": 0xfff9fbe7, "lime100": 0xfff0f4c3, "lime200": 0xffe6ee9c,
    "lime300": 0xffdce775, "lime400": 0xffd4e157, "lime500": 0xffcddc39,
    "lime600": 0xffc0ca33, "lime700": 0xffafb42b, "lime800": 0xff9e9d24,
    "lime900": 0xff827717, "limeaccent100": 0xfff4ff81, "limeaccent200": 0xffeeff41,
    "limeaccent400": 0xffc6ff00, "limeaccent700": 0xffaeea00,
    "yellow50": 0xfffffde7, "yellow100": 0xfffff9c4, "yellow200": 0xfffff59d,
    "yellow300": 0xfffff176, "yellow400": 0xffffee58, "yellow500": 0xffffeb3b,
    "yellow600": 0xfffdd835, "yellow700": 0xfffbc02d, "yellow800": 0xfff9a825,
    "yellow900": 0xfff57f17, "yellowaccent100": 0xffffff8d, "yellowaccent200": 0xffffff00,
    "yellowaccent400": 0xffffea00, "yellowaccent700": 0xffffd600,
    "amber50": 0xfffff8e1, "amber100": 0xffffecb3, "amber200": 0xffffe082,
    "amber300": 0xffffd54f, "amber400": 0xffffca28, "amber500": 0xffffc107,
    "amber600": 0xffffb300, "amber700": 0xffffa000, "amber800": 0xffff8f00,
    "amber900": 0xffff6f00, "amberaccent100": 0xffffe57f, "amberaccent200": 0xffffd740,
    "amberaccent400": 0xffffc400, "amberaccent700": 0xffffab00,
    "orange50": 0xfffff3e0, "orange100": 0xffffe0b2, "orange200": 0xffffcc80,
    "orange300": 0xffffb74d, "orange400": 0xffffa726, "orange500": 0xffff9800,
    "orange600": 0xfffb8c00, "orange700": 0xfff57c00, "orange800": 0xffef6c00,
    "orange900": 0xffe65100, "orangeaccent100": 0xffffd180, "orangeaccent200": 0xffffab40,
    "orangeaccent400": 0xffff9100, "orangeaccent700": 0xffff6d00,
    "deeporange50": 0xfffbe9e7, "deeporange100": 0xffffccbc, "deeporange200": 0xffffab91,
    "deeporange300": 0xffff8a65, "deeporange400": 0xffff7043, "deeporange500": 0xffff5722,
    "deeporange600": 0xfff4511e, "deeporange700": 0xffe64a19, "deeporange800": 0xffd84315,
    "deeporange900": 0xffbf360c, "deeporangeaccent100": 0xffff9e80,
    "deeporangeaccent200": 0xffff6e40, "deeporangeaccent400": 0xffff3d00,
    "deeporangeaccent700": 0xffdd2c00,
    "brown50": 0xffefebe9, "brown100": 0xffd7ccc8, "brown200": 0xffbcaaa4,
    "brown300": 0xffa1887f, "brown400": 0xff8d6e63, "brown500": 0xff795548,
    "brown600": 0xff6d4c41, "brown700": 0xff5d4037, "brown800": 0xff4e342e,
    "brown900": 0xff3e2723,
    "grey50": 0xfffafafa, "grey100": 0xfff5f5f5, "grey200": 0xffeeeeee,
    "grey300": 0xffe0e0e0, "grey400": 0xffbdbdbd, "grey500": 0xff9e9e9e,
    "grey600": 0xff757575, "grey700": 0xff616161, "grey800": 0xff424242,
    "grey900": 0xff212121,
    "bluegrey50": 0xffeceff1, "bluegrey100": 0xffcfd8dc, "bluegrey200": 0xffb0bec5,
    "bluegrey300": 0xff90a4ae, "bluegrey400": 0xff78909c, "bluegrey500": 0xff607d8b,
    "bluegrey600": 0xff546e7a, "bluegrey700": 0xff455a64, "bluegrey800": 0xff37474f,
    "bluegrey900": 0xff263238,
]

private let materialDefaults: [String: String] = [
    "red": "red500", "pink": "pink500", "purple": "purple500",
    "deeppurple": "deeppurple500", "indigo": "indigo500", "blue": "blue500",
    "lightblue": "lightblue500", "cyan": "cyan500", "teal": "teal500",
    "green": "green500", "lightgreen": "lightgreen500", "lime": "lime500",
    "yellow": "yellow500", "amber": "amber500", "orange": "orange500",
    "deeporange": "deeporange500", "brown": "brown500", "grey": "grey500",
    "bluegrey": "bluegrey500", "redaccent": "redaccent200", "pinkaccent": "pinkaccent200",
    "purpleaccent": "purpleaccent200", "deeppurpleaccent": "deeppurpleaccent200",
    "indigoaccent": "indigoaccent200", "blueaccent": "blueaccent200",
    "lightblueaccent": "lightblueaccent200", "cyanaccent": "cyanaccent200",
    "tealaccent": "tealaccent200", "greenaccent": "greenaccent200",
    "lightgreenaccent": "lightgreenaccent200", "limeaccent": "limeaccent200",
    "yellowaccent": "yellowaccent200", "amberaccent": "amberaccent200",
    "orangeaccent": "orangeaccent200", "deeporangeaccent": "deeporangeaccent200",
]

public func parseColor(_ value: String?, _ defaultColor: Color? = nil) -> Color? {
    guard let value, !value.isEmpty else { return defaultColor }
    let components = value.split(separator: ",", maxSplits: 1).map(String.init)
    let colorValue = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
    let opacity = components.count > 1 ? parseDouble(components[1], 1)! : 1
    let normalized = colorValue.lowercased().replacingOccurrences(
        of: #"[_\-\s]+"#, with: "", options: .regularExpression)

    let color: Color?
    if colorValue.hasPrefix("#") {
        color = colorFromARGBHex(String(colorValue.dropFirst()))
    } else if normalized.hasPrefix("0x") {
        color = colorFromARGBHex(String(normalized.dropFirst(2)))
    } else if normalized == "transparent" {
        color = .clear
    } else if normalized == "white" {
        color = .white
    } else if normalized == "black" {
        color = .black
    } else if let percent = Int(normalized.dropFirst(normalized.hasPrefix("white") ? 5 : 5)),
              normalized.hasPrefix("white") {
        color = .white.opacity(Double(percent) / 100)
    } else if let percent = Int(normalized.dropFirst(5)), normalized.hasPrefix("black") {
        color = .black.opacity(Double(percent) / 100)
    } else if let key = materialDefaults[normalized], let argb = materialColors[key] {
        color = colorFromARGB(argb)
    } else if let argb = materialColors[normalized] {
        color = colorFromARGB(argb)
    } else {
        color = appleNamedColor(normalized)
    }
    return color?.opacity(opacity) ?? defaultColor
}

private func colorFromARGBHex(_ value: String) -> Color? {
    let hex = value.count == 6 ? "ff" + value : value
    guard hex.count == 8, let argb = UInt32(hex, radix: 16) else { return nil }
    return colorFromARGB(argb)
}

private func colorFromARGB(_ value: UInt32) -> Color {
    Color(
        .sRGB,
        red: Double((value >> 16) & 0xff) / 255,
        green: Double((value >> 8) & 0xff) / 255,
        blue: Double(value & 0xff) / 255,
        opacity: Double((value >> 24) & 0xff) / 255
    )
}

private func appleNamedColor(_ value: String) -> Color? {
    #if os(iOS)
    let colors: [String: UIColor] = [
        "activeblue": .systemBlue, "activegreen": .systemGreen, "activeorange": .systemOrange,
        "cupertinowhite": .white, "cupertinoblack": .black, "inactivegray": .systemGray,
        "destructivered": .systemRed, "systemblue": .systemBlue, "systemgreen": .systemGreen,
        "systemmint": .systemMint, "systemindigo": .systemIndigo, "systemorange": .systemOrange,
        "systempink": .systemPink, "systembrown": .systemBrown, "systempurple": .systemPurple,
        "systemred": .systemRed, "systemteal": .systemTeal, "systemcyan": .systemCyan,
        "systemyellow": .systemYellow, "systemgrey": .systemGray, "systemgrey2": .systemGray2,
        "systemgrey3": .systemGray3, "systemgrey4": .systemGray4, "systemgrey5": .systemGray5,
        "systemgrey6": .systemGray6, "label": .label, "secondarylabel": .secondaryLabel,
        "tertiarylabel": .tertiaryLabel, "quaternarylabel": .quaternaryLabel,
        "systemfill": .systemFill, "secondarysystemfill": .secondarySystemFill,
        "tertiarysystemfill": .tertiarySystemFill, "quaternarysystemfill": .quaternarySystemFill,
        "placeholdertext": .placeholderText, "systembackground": .systemBackground,
        "secondarysystembackground": .secondarySystemBackground,
        "tertiarysystembackground": .tertiarySystemBackground,
        "systemgroupedbackground": .systemGroupedBackground,
        "secondarysystemgroupedbackground": .secondarySystemGroupedBackground,
        "tertiarysystemgroupedbackground": .tertiarySystemGroupedBackground,
        "separator": .separator, "opaqueseparator": .opaqueSeparator, "link": .link,
    ]
    return colors[value].map(Color.init(uiColor:))
    #elseif os(macOS)
    let colors: [String: NSColor] = [
        "activeblue": .systemBlue, "activegreen": .systemGreen, "activeorange": .systemOrange,
        "cupertinowhite": .white, "cupertinoblack": .black, "inactivegray": .systemGray,
        "destructivered": .systemRed, "systemblue": .systemBlue, "systemgreen": .systemGreen,
        "systemindigo": .systemIndigo, "systemorange": .systemOrange, "systempink": .systemPink,
        "systembrown": .systemBrown, "systempurple": .systemPurple, "systemred": .systemRed,
        "systemteal": .systemTeal, "systemyellow": .systemYellow, "label": .labelColor,
        "secondarylabel": .secondaryLabelColor, "tertiarylabel": .tertiaryLabelColor,
        "quaternarylabel": .quaternaryLabelColor, "placeholdertext": .placeholderTextColor,
        "systembackground": .windowBackgroundColor, "separator": .separatorColor,
        "link": .linkColor,
    ]
    return colors[value].map(Color.init(nsColor:))
    #endif
}
