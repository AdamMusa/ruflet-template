import RufletEngine
import RufletProtocol
import SwiftUI

/// The Material button variants, mapped onto the native equivalent.
///
/// Flet exposes six flavours that differ only in fill and border; SwiftUI has
/// the same distinctions, so the variant picks the styling rather than a
/// separate view.
enum ButtonVariant {
  case elevated
  case filled
  case filledTonal
  case outlined
  case text
  case icon
  case filledIcon
  case filledTonalIcon
  case outlinedIcon
  case floatingAction

  init(wireType: String) {
    switch wireType {
    case "FilledButton": self = .filled
    case "FilledTonalButton": self = .filledTonal
    case "OutlinedButton": self = .outlined
    case "TextButton": self = .text
    case "IconButton": self = .icon
    case "FilledIconButton": self = .filledIcon
    case "FilledTonalIconButton": self = .filledTonalIcon
    case "OutlinedIconButton": self = .outlinedIcon
    case "FloatingActionButton": self = .floatingAction
    default: self = .elevated
    }
  }

  /// The four icon-button wire types differ only in their container, so they
  /// share one label and one style and are told apart by the palette.
  var isIconButton: Bool {
    switch self {
    case .icon, .filledIcon, .filledTonalIcon, .outlinedIcon: return true
    default: return false
    }
  }
}

/// The Apple-native button family used when the DSL did not supply a visual
/// style. This is deliberately semantic rather than geometric: SwiftUI is
/// responsible for the platform's padding, corner shape, colours and pressed
/// appearance.
enum NativeButtonAppearance: Equatable {
  case automatic
  case bordered
  case borderedProminent
  case plain
  case borderless

  static func resolve(_ variant: ButtonVariant) -> NativeButtonAppearance {
    switch variant {
    case .filled, .floatingAction, .filledIcon:
      return .borderedProminent
    case .elevated:
      return .automatic
    case .filledTonal, .outlined, .filledTonalIcon, .outlinedIcon:
      return .bordered
    case .text:
      return .plain
    case .icon:
      return .borderless
    }
  }
}

/// Every Material button: `Button`, `TextButton`, `FilledButton`,
/// `FilledTonalButton`, `OutlinedButton`, the icon buttons and the FAB.
///
/// `content` is either a string or a nested control, because Ruflet maps a
/// button's `text` onto `content` (`Page#text_maps_to_content?`).
struct ButtonControlView: View {
  let node: ControlNode
  let variant: ButtonVariant

  @Environment(\.rufletEvents) private var events
  @Environment(\.openURL) private var openURL

  @ViewBuilder
  var body: some View {
    if let message = ButtonPresentation.validationMessage(node, variant: variant) {
      Text(message).font(.caption).foregroundStyle(.red)
    } else if variant.isIconButton, node.bool("adaptive") == true {
      CupertinoButtonControlView(node: node)
    } else {
      NativeButtonPresentation(node: node, variant: variant) {
        Button(action: activate) {
          label
        }
      }
      .modifier(FocusReporter(node: node, events: events))
      .modifier(LongPressReporter(node: node, events: events))
      .modifier(HoverReporter(node: node, events: events))
      .modifier(VisualDensityPadding(value: node.props["visual_density"]))
      .modifier(TapFeedback(enabled: node.bool("enable_feedback") != false))
      .disabled(node.bool("disabled") ?? false)
    }
  }

  /// `url` opens directly, the way Flet's buttons do, *and* still reports the
  /// click so a Ruby handler on the same control runs.
  private func activate() {
    if let url = node.string("url").flatMap(URL.init(string:)) {
      openURL(url)
    }
    events.fire(node, "click")
  }

  private var selected: Bool { node.bool("selected") ?? false }

  /// `content` is either a nested control or a plain string.
  ///
  /// `Ruflet.button("Save")` puts the label straight into `content`, and
  /// `Page#update(button, text: "Save")` is rewritten to `content` too
  /// (`Page#text_maps_to_content?`), so a button's caption can arrive as a
  /// string in either slot. All four spellings resolve here.
  private var captionText: String? {
    if let text = node.string("content"), node.props["content"]?.controlID == nil {
      return text
    }
    return node.string("text") ?? node.string("label")
  }

  private var iconSize: CGFloat? {
    node.double("icon_size").map { CGFloat($0) }
  }

  @ViewBuilder
  private var label: some View {
    let icon = node.props["icon"]

    if variant.isIconButton {
      let chosenIcon = selected ? (node.props["selected_icon"] ?? icon) : icon
      if let chosenID = chosenIcon?.controlID {
        ControlView(id: chosenID, axis: .none)
      } else if chosenIcon != nil {
        RufletIcon(
          value: chosenIcon,
          size: iconSize,
          color: IconButtonPresentation(node: node).foreground)
      } else if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else if let caption = captionText {
        Text(caption)
      }
    } else if variant == .floatingAction {
      HStack {
        if icon != nil {
          RufletIcon(value: icon, size: iconSize, color: nil)
        }
        // The round FAB shows its icon *or* its content; only the extended one
        // shows both.
        if icon == nil || FloatingActionPresentation(node: node).isExtended {
          if let contentID = node.controlID(forKey: "content") {
            ControlView(id: contentID, axis: .none)
          } else if let caption = captionText {
            Text(caption)
          }
        }
      }
    } else {
      HStack {
        if icon != nil {
          RufletIcon(
            value: icon,
            size: iconSize,
            color: MaterialPalette.color(node.string("icon_color")))
        }
        if let contentID = node.controlID(forKey: "content") {
          ControlView(id: contentID, axis: .none)
        } else if let caption = captionText {
          Text(caption)
        }
      }
    }
  }
}

/// Keeps Flutter constructor defaults distinct from Flet's explicit-style
/// defaults. `parseButtonStyle(nil)` returns nil; `parseButtonStyle({})`
/// returns the common primary/surface style.
struct ButtonPresentation {
  let node: ControlNode
  let variant: ButtonVariant

  var style: [String: RufletValue]? {
    node.internals["style"]?.mapValue ?? node.props["style"]?.mapValue
  }
  var hasExplicitStyle: Bool { style != nil }
  var requiresCustomStyle: Bool { !(style?.isEmpty ?? true) }

  static func validationMessage(_ node: ControlNode, variant: ButtonVariant) -> String? {
    if variant == .floatingAction,
      node.props["icon"] == nil && node.props["content"] == nil
    {
      return
        "FloatingActionButton has nothing to display. Provide at minimum one of these: icon, content"
    }
    if variant.isIconButton {
      let visible =
        node.controlID(forKey: "content") != nil
        || !(node.string("content") ?? "").isEmpty
      if node.props["icon"] == nil && !visible {
        return "IconButton must have either icon or a visible content specified."
      }
    } else if variant != .floatingAction,
      node.props["icon"] != nil && node.props["content"] == nil
    {
      return "Error displaying Button: \"icon\" must be specified together with \"content\""
    }
    return nil
  }

  var foregroundToken: String {
    if hasExplicitStyle {
      return style?["color"]?.stringValue ?? node.string("color") ?? "primary"
    }
    switch variant {
    case .filled: return "onprimary"
    case .filledTonal: return "onsecondarycontainer"
    default: return "primary"
    }
  }

  var backgroundToken: String {
    if hasExplicitStyle {
      return style?["bgcolor"]?.stringValue ?? node.string("bgcolor") ?? "surface"
    }
    switch variant {
    case .elevated: return "surfacecontainerlow"
    case .filled: return "primary"
    case .filledTonal: return "secondarycontainer"
    default: return "transparent"
    }
  }

  var padding: EdgeInsets {
    let states = node.widgetStates()
    if let value = RufletWidgetStateProperty.resolve(style?["padding"], in: states),
      let parsed = ControlProps.edgeInsets(value)
    {
      return parsed
    }
    if hasExplicitStyle { return EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8) }
    if variant == .text { return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12) }
    return EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
  }

  var minimumSize: ControlProps.SizeConstraints {
    if let value = style?["minimum_size"], let parsed = ControlProps.sizeConstraints(value) {
      return parsed
    }
    return .init(minWidth: 64, minHeight: 40)
  }

  var fixedSize: ControlProps.SizeConstraints? {
    style?["fixed_size"].flatMap(ControlProps.sizeConstraints)
  }

  var maximumSize: ControlProps.SizeConstraints? {
    style?["maximum_size"].flatMap(ControlProps.sizeConstraints)
  }

  var elevation: Double {
    if let explicit = RufletWidgetStateProperty.resolve(
      style?["elevation"], in: node.widgetStates())?.doubleValue
    {
      return explicit
    }
    if hasExplicitStyle { return node.double("elevation") ?? 1 }
    return variant == .elevated ? 1 : 0
  }

  var radius: CGFloat {
    if let value = style?["shape"]?.mapValue?["radius"],
      let parsed = ControlProps.cornerRadius(value)
    {
      return parsed
    }
    return 20
  }

  var alignment: Alignment {
    ControlProps.alignment(style?["alignment"]) ?? .center
  }

  var textStyle: RufletTextStyle {
    RufletTextStyle(map: style?["text_style"]?.mapValue ?? [:])
  }

  func elevation(state: RufletWidgetState?) -> Double {
    var states = node.widgetStates()
    if let state { states.insert(state) }
    if let value = RufletWidgetStateProperty.resolve(style?["elevation"], in: states)?.doubleValue {
      return value
    }
    if hasExplicitStyle { return node.double("elevation") ?? 1 }
    if variant == .elevated, state == .hovered { return 3 }
    return variant == .elevated ? 1 : 0
  }

  func border(state: RufletWidgetState?) -> (Color, CGFloat)? {
    var states = node.widgetStates()
    if let state { states.insert(state) }
    if let explicit = ControlProps.statefulBorderSide(style?["side"], in: states) {
      return (explicit.color ?? .clear, explicit.width)
    }
    guard variant == .outlined else { return nil }
    if node.bool("disabled") == true {
      return (MaterialPalette.color("onsurface,0.12", default: .clear), 1)
    }
    return (MaterialPalette.color(state == .focused ? "primary" : "outline", default: .clear), 1)
  }

  func color(_ key: String, state: RufletWidgetState? = nil) -> Color? {
    var states = node.widgetStates()
    if let state { states.insert(state) }
    if let explicit = style?[key] {
      return MaterialPalette.color(stateful: explicit, in: states)
    }
    if hasExplicitStyle {
      if key == "color" { return MaterialPalette.color(foregroundToken) }
      if key == "bgcolor" { return MaterialPalette.color(backgroundToken) }
      if key == "overlay_color", state != nil { return MaterialPalette.color("primary,0.08") }
    }
    // A styleless control must not receive Flutter's Material colour roles.
    // Its native ButtonStyle resolves the Apple platform defaults instead.
    guard hasExplicitStyle else { return nil }
    if key == "color" {
      if node.bool("disabled") == true { return MaterialPalette.color("onsurface,0.38") }
      return MaterialPalette.color(foregroundToken)
    }
    if key == "bgcolor" {
      if node.bool("disabled") == true,
        variant == .elevated || variant == .filled || variant == .filledTonal
      {
        return MaterialPalette.color("onsurface,0.12")
      }
      return MaterialPalette.color(backgroundToken)
    }
    if key == "overlay_color", let state {
      return MaterialPalette.color("\(foregroundToken),\(state == .hovered ? "0.08" : "0.10")")
    }
    return nil
  }
}

/// Uses Apple's button families and only applies colours when Ruby explicitly
/// supplied them. Omitted values therefore inherit the platform appearance.
private struct NativeButtonPresentation<Content: View>: View {
  let node: ControlNode
  let variant: ButtonVariant
  @ViewBuilder let content: () -> Content

  @ViewBuilder
  var body: some View {
    switch variant {
    case .filled, .filledTonal, .outlined, .text, .elevated:
      let presentation = ButtonPresentation(node: node, variant: variant)
      if presentation.requiresCustomStyle {
        content().buttonStyle(RufletMaterialButtonStyle(presentation: presentation))
      } else {
        nativeButton(content(), appearance: NativeButtonAppearance.resolve(variant))
      }
    case .floatingAction:
      let geometry = FloatingActionPresentation(node: node)
      if geometry.requiresCustomRendering {
        content()
          .buttonStyle(
            RufletFloatingActionStyle(
              background: geometry.background,
              foreground: geometry.foreground,
              overlay: geometry.overlay,
              radius: geometry.radius,
              width: geometry.width,
              height: geometry.height,
              padding: geometry.padding,
              elevation: geometry.elevation(),
              hoverElevation: geometry.elevation(hovered: true),
              pressedElevation: geometry.pressedElevation,
              shadow: MaterialPalette.color(node.string("shadow_color"))))
      } else if geometry.isExtended {
        content()
          .buttonStyle(.borderedProminent)
          .modifier(NativeButtonShape(circular: false))
          .modifier(OptionalTint(color: geometry.background))
          .modifier(OptionalForeground(color: geometry.foreground))
      } else {
        content()
          .buttonStyle(.borderedProminent)
          .modifier(NativeButtonShape(circular: true))
          .controlSize(geometry.isMini ? .small : .regular)
          .modifier(OptionalTint(color: geometry.background))
          .modifier(OptionalForeground(color: geometry.foreground))
      }
    case .icon, .filledIcon, .filledTonalIcon, .outlinedIcon:
      let presentation = IconButtonPresentation(node: node)
      if presentation.requiresCustomRendering {
        content()
          .buttonStyle(
            RufletIconButtonStyle(
              foreground: presentation.foreground,
              background: presentation.background,
              outline: presentation.outline,
              highlight: MaterialPalette.color(node.string("highlight_color")),
              splash: MaterialPalette.color(node.string("splash_color")),
              padding: presentation.padding,
              alignment: presentation.alignment,
              constraints: presentation.constraints))
      } else {
        nativeIconButton(content(), appearance: NativeButtonAppearance.resolve(variant))
      }
    }
  }

  @ViewBuilder
  private func nativeButton<V: View>(_ view: V, appearance: NativeButtonAppearance) -> some View {
    switch appearance {
    case .automatic: view.buttonStyle(.automatic)
    case .bordered: view.buttonStyle(.bordered)
    case .borderedProminent: view.buttonStyle(.borderedProminent)
    case .plain: view.buttonStyle(.plain)
    case .borderless: view.buttonStyle(.borderless)
    }
  }

  @ViewBuilder
  private func nativeIconButton<V: View>(
    _ view: V, appearance: NativeButtonAppearance
  ) -> some View {
    switch appearance {
    case .automatic:
      view.buttonStyle(.automatic)
    case .bordered:
      view.buttonStyle(.bordered).modifier(NativeButtonShape(circular: true))
    case .borderedProminent:
      view.buttonStyle(.borderedProminent).modifier(NativeButtonShape(circular: true))
    case .plain:
      view.buttonStyle(.plain)
    case .borderless:
      view.buttonStyle(.borderless)
    }
  }
}

/// `buttonBorderShape` gained a macOS deployment restriction after the iOS
/// API. Keep the native shape where it is available and otherwise retain the
/// native button's own shape instead of drawing a substitute.
private struct NativeButtonShape: ViewModifier {
  let circular: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    #if os(macOS)
      if #available(macOS 14, *) {
        content.buttonBorderShape(circular ? .circle : .capsule)
      } else {
        content
      }
    #else
      content.buttonBorderShape(circular ? .circle : .capsule)
    #endif
  }
}

/// The container an icon button draws behind its glyph.
///
/// Flet only reaches `parseButtonStyle` when Ruby supplied a `style`, so a
/// styleless icon button is left to Flutter's own `_IconButtonDefaultsM3`
/// family. Both paths are represented: the pinned Flet default (`primary`)
/// applies when a style is present, and the variant palette applies otherwise.
struct IconButtonPresentation {
  let node: ControlNode

  private var style: [String: RufletValue]? {
    node.internals["style"]?.mapValue ?? node.props["style"]?.mapValue
  }

  static func palette(for node: ControlNode) -> RufletThemeDefaults.IconButtonPalette {
    var palette = RufletThemeDefaults.iconButtonPalette(
      control: node.type,
      selected: node.bool("selected"),
      disabled: node.bool("disabled") == true)
    if (node.internals["style"]?.mapValue ?? node.props["style"]?.mapValue) != nil,
      node.bool("disabled") != true
    {
      palette.foreground =
        RufletThemeDefaults.colorToken(control: node.type, property: "color")
        ?? palette.foreground
      palette.background = "transparent"
      palette.outline = nil
    }
    return palette
  }

  private var palette: RufletThemeDefaults.IconButtonPalette { Self.palette(for: node) }

  var requiresCustomRendering: Bool {
    style?.isEmpty == false
      || [
        "bgcolor", "icon_color", "disabled_color", "selected_icon_color",
        "padding", "alignment", "size_constraints", "splash_radius",
        "highlight_color", "splash_color",
      ].contains { node.props[$0] != nil }
  }

  var foreground: Color? {
    if node.bool("disabled") == true {
      return MaterialPalette.color(node.string("disabled_color"))
        ?? MaterialPalette.color(palette.foreground)
    }
    if node.bool("selected") == true,
      let onColor = MaterialPalette.color(node.string("selected_icon_color"))
    {
      return onColor
    }
    return MaterialPalette.color(node.string("icon_color"))
      ?? MaterialPalette.color(style?["icon_color"]?.stringValue)
      ?? MaterialPalette.color(style?["color"]?.stringValue)
      ?? MaterialPalette.color(palette.foreground)
  }

  var background: Color? {
    MaterialPalette.color(style?["bgcolor"]?.stringValue)
      ?? MaterialPalette.color(node.string("bgcolor"))
      ?? MaterialPalette.color(palette.background)
  }

  var outline: Color? { MaterialPalette.color(palette.outline) }

  var padding: EdgeInsets {
    ControlProps.edgeInsets(node.props["padding"])
      ?? ControlProps.edgeInsets(style?["padding"])
      ?? RufletThemeDefaults.materialIconButtonPadding
  }

  var alignment: Alignment {
    ControlProps.alignment(node.props["alignment"]) ?? .center
  }

  /// `size_constraints` is Flutter's `BoxConstraints`; `splash_radius` is the
  /// older way of naming the same target, so it stands in when no constraints
  /// were given. Absent both, the button is Material's 40pt target.
  var constraints: ControlProps.SizeConstraints {
    if let explicit = ControlProps.sizeConstraints(node.props["size_constraints"]) {
      return explicit
    }
    let side =
      node.double("splash_radius").map { CGFloat($0) * 2 }
      ?? RufletThemeDefaults.materialIconButtonTargetSize
    return ControlProps.SizeConstraints(minWidth: side, minHeight: side)
  }
}

/// The floating action button's geometry and colours, which Flet names
/// separately from the other button families.
struct FloatingActionPresentation {
  let node: ControlNode

  var isMini: Bool { node.bool("mini") == true }

  var requiresCustomRendering: Bool {
    [
      "shape", "elevation", "focus_elevation", "hover_elevation",
      "highlight_elevation", "disabled_elevation", "splash_color",
      "hover_color", "focus_color", "shadow_color",
    ].contains { node.props[$0] != nil }
  }

  /// A FAB carrying both an icon and content is `FloatingActionButton.extended`
  /// — a pill that grows with its label rather than a fixed square.
  var isExtended: Bool { node.props["icon"] != nil && node.props["content"] != nil }

  var side: CGFloat {
    isExtended
      ? RufletThemeDefaults.floatingActionButtonSize
      : (isMini
        ? RufletThemeDefaults.floatingActionButtonMiniSize
        : RufletThemeDefaults.floatingActionButtonSize)
  }

  var width: CGFloat? { isExtended ? nil : side }
  var height: CGFloat { side }

  var padding: EdgeInsets {
    isExtended ? RufletThemeDefaults.floatingActionButtonExtendedPadding : EdgeInsets()
  }

  var radius: CGFloat {
    if let explicit = ControlProps.cornerRadius(node.map("shape")?["radius"]) { return explicit }
    if isExtended { return height / 2 }
    return isMini
      ? RufletThemeDefaults.floatingActionButtonMiniRadius
      : RufletThemeDefaults.floatingActionButtonRadius
  }

  var background: Color? {
    MaterialPalette.color(for: node, property: "bgcolor")
  }

  var foreground: Color? {
    MaterialPalette.color(for: node, property: "foreground_color")
  }

  /// SwiftUI has no hover or focus state inside a `ButtonStyle`, so the
  /// pressed tint is the one Flet's splash colour maps onto; the hover and
  /// focus colours stand in for it when only they were given.
  var overlay: Color? {
    MaterialPalette.color(node.string("splash_color"))
      ?? MaterialPalette.color(node.string("hover_color"))
      ?? MaterialPalette.color(node.string("focus_color"))
  }

  /// The FAB's resting height. `hovered` is passed in because SwiftUI keeps
  /// hover inside the view, and `focus_elevation` folds into it: a SwiftUI
  /// `ButtonStyle` sees neither state, so the raised height they both name is
  /// applied to the one the platform does report.
  func elevation(hovered: Bool = false) -> Double {
    if node.bool("disabled") == true {
      return node.double("disabled_elevation")
        ?? RufletThemeDefaults.floatingActionButtonDisabledElevation
    }
    if hovered {
      return node.double("hover_elevation")
        ?? node.double("focus_elevation")
        ?? RufletThemeDefaults.floatingActionButtonHoverElevation
    }
    return node.double("elevation") ?? RufletThemeDefaults.floatingActionButtonElevation
  }

  var pressedElevation: Double {
    if node.bool("disabled") == true { return elevation() }
    return node.double("highlight_elevation")
      ?? RufletThemeDefaults.floatingActionButtonHighlightElevation
  }
}

/// The exact common defaults Flet 0.80.5 supplies to `parseButtonStyle` for
/// Button/Filled/FilledTonal/Outlined/TextButton. Flutter constructors still
/// provide interaction behavior; this style only resolves Flet's shared
/// Material presentation instead of letting each SwiftUI style invent a
/// different platform fallback.
private struct RufletMaterialButtonStyle: ButtonStyle {
  let presentation: ButtonPresentation
  @State private var hovering = false

  func makeBody(configuration: Configuration) -> some View {
    let p = presentation
    let fixed = p.fixedSize
    let maximum = p.maximumSize
    let shape = RoundedRectangle(cornerRadius: p.radius)
    let activeState: RufletWidgetState? =
      configuration.isPressed ? .pressed : (hovering ? .hovered : nil)
    let elevation = p.elevation(state: activeState)
    let border = p.border(state: activeState)
    configuration.label
      .rufletTextStyle(p.textStyle)
      .padding(p.padding)
      .frame(
        minWidth: fixed?.minWidth ?? p.minimumSize.minWidth,
        maxWidth: fixed?.maxWidth ?? maximum?.maxWidth,
        minHeight: fixed?.minHeight ?? p.minimumSize.minHeight,
        maxHeight: fixed?.maxHeight ?? maximum?.maxHeight,
        alignment: p.alignment
      )
      .foregroundColor(
        p.color("color", state: configuration.isPressed ? .pressed : (hovering ? .hovered : nil))
      )
      .background(
        p.color("bgcolor", state: configuration.isPressed ? .pressed : (hovering ? .hovered : nil))
          ?? .clear,
        in: shape
      )
      .overlay {
        if configuration.isPressed || hovering {
          shape.fill(
            p.color("overlay_color", state: configuration.isPressed ? .pressed : .hovered)
              ?? .clear)
        }
      }
      .overlay {
        if let border {
          shape.strokeBorder(border.0, lineWidth: border.1)
        }
      }
      .shadow(
        color: elevation > 0
          ? (MaterialPalette.color(p.style?["shadow_color"]?.stringValue) ?? .black.opacity(0.2))
          : .clear,
        radius: CGFloat(max(elevation, 0)), y: CGFloat(max(elevation, 0) / 2)
      )
      .contentShape(shape)
      .onHover { hovering = $0 }
  }
}

/// The icon button: a glyph inside a Material target, over whichever container
/// its variant draws. The splash colour tints it while the pointer is down and
/// the highlight colour while it rests, which is what Material's ink does with
/// the two.
private struct RufletIconButtonStyle: ButtonStyle {
  let foreground: Color?
  let background: Color?
  let outline: Color?
  let highlight: Color?
  let splash: Color?
  let padding: EdgeInsets
  let alignment: Alignment
  let constraints: ControlProps.SizeConstraints

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundColor(foreground)
      .padding(padding)
      .frame(
        minWidth: constraints.minWidth, maxWidth: constraints.maxWidth,
        minHeight: constraints.minHeight, maxHeight: constraints.maxHeight,
        alignment: alignment
      )
      .background(Circle().fill(background ?? .clear))
      .background(
        Circle().fill(configuration.isPressed ? (splash ?? .clear) : (highlight ?? .clear))
      )
      .overlay(Circle().strokeBorder(outline ?? .clear))
      .contentShape(Circle())
  }
}

/// The floating action button, whose shape, size and elevation Flet names
/// separately from the other families. `width` is nil for the extended form,
/// which grows with its label instead of staying square.
private struct RufletFloatingActionStyle: ButtonStyle {
  let background: Color?
  let foreground: Color?
  let overlay: Color?
  let radius: CGFloat
  let width: CGFloat?
  let height: CGFloat
  let padding: EdgeInsets
  let elevation: Double
  let hoverElevation: Double
  let pressedElevation: Double
  let shadow: Color?

  @State private var hovering = false

  func makeBody(configuration: Configuration) -> some View {
    let shape = RoundedRectangle(cornerRadius: radius)
    let raised =
      configuration.isPressed
      ? pressedElevation
      : (hovering ? hoverElevation : elevation)
    return configuration.label
      .foregroundColor(foreground)
      .padding(padding)
      .frame(minWidth: width, minHeight: height)
      .background(shape.fill(background ?? .accentColor))
      .overlay(shape.fill(configuration.isPressed ? (overlay ?? .clear) : .clear))
      .contentShape(shape)
      .shadow(
        color: shadow ?? .black.opacity(0.25),
        radius: CGFloat(max(raised, 0)), y: CGFloat(max(raised, 0) / 2)
      )
      .onHover { hovering = $0 }
  }
}

/// `enable_feedback` is the platform tap feedback Material plays on a control.
struct TapFeedback: ViewModifier {
  let enabled: Bool

  func body(content: Content) -> some View {
    #if os(iOS)
      if enabled {
        return AnyView(
          content.simultaneousGesture(
            TapGesture().onEnded {
              UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }))
      }
    #endif
    return AnyView(content)
  }
}

struct OptionalTint: ViewModifier {
  let color: Color?
  func body(content: Content) -> some View {
    if let color { content.tint(color) } else { content }
  }
}

struct OptionalForeground: ViewModifier {
  let color: Color?
  func body(content: Content) -> some View {
    if let color { content.foregroundColor(color) } else { content }
  }
}

/// `Chip` — a compact, optionally selectable, optionally deletable token.
struct ChipControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var pressed = false

  @ViewBuilder
  var body: some View {
    if let validationMessage = ChipPresentation.validationMessage(node) {
      Text(validationMessage)
        .font(.caption)
        .foregroundStyle(.red)
    } else if ChipPresentation.requiresCustomRendering(node) {
      materialChip
    } else {
      nativeChip
    }
  }

  /// Apple has no public SwiftUI token/chip primitive. A compact native
  /// bordered button is the closest semantic equivalent and, importantly,
  /// leaves its colour, metrics, corner treatment and pressed appearance to
  /// the platform. Explicit Material styling still uses `materialChip`.
  private var nativeChip: some View {
    let selected = node.bool("selected") ?? false
    let interactive = node.handlesEvent("select") || node.handlesEvent("click")

    return HStack(spacing: nil) {
      Button {
        activateChip(selected: selected)
      } label: {
        nativeChipLabel(selected: selected)
      }
      .modifier(NativeChipButtonStyle(selected: selected))
      .allowsHitTesting(interactive && node.bool("disabled") != true)
      .accessibilityAddTraits(interactive ? .isButton : [])

      if node.handlesEvent("delete") {
        Button {
          events.fire(node, "delete")
        } label: {
          nativeDeleteIcon
        }
        .buttonStyle(.borderless)
        .help(ChipPresentation.deleteTooltip(node) ?? "")
        .modifier(ChipSlotConstraints(value: node.props["delete_icon_size_constraints"]))
      }
    }
    .controlSize(.small)
    .disabled(node.bool("disabled") == true)
    .modifier(FocusReporter(node: node, events: events))
  }

  @ViewBuilder
  private func nativeChipLabel(selected: Bool) -> some View {
    HStack {
      if selected, node.bool("show_checkmark") != false {
        Image(systemName: "checkmark")
      } else if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
          .modifier(ChipSlotConstraints(value: node.props["leading_size_constraints"]))
      }
      label
    }
  }

  @ViewBuilder
  private var nativeDeleteIcon: some View {
    if node.props["delete_icon"] != nil {
      RufletIcon(value: node.props["delete_icon"], size: nil, color: nil)
    } else {
      Image(systemName: "xmark.circle")
    }
  }

  private func activateChip(selected: Bool) {
    guard node.bool("disabled") != true else { return }
    guard !(node.handlesEvent("select") && node.handlesEvent("click")) else { return }
    if node.handlesEvent("select") {
      events.commit(node, key: "selected", value: .bool(!selected), event: "select")
    } else if node.handlesEvent("click") {
      events.fire(node, "click")
    }
  }

  private var materialChip: some View {
    let selected = node.bool("selected") ?? false

    return HStack(spacing: 0) {
      // A selected chip shows the checkmark in place of its leading icon,
      // which is what Material's `showCheckmark` does.
      if selected, node.bool("show_checkmark") != false {
        Image(systemName: "checkmark")
          .font(.system(size: ChipPresentation.defaultIconSize))
          .foregroundColor(
            MaterialPalette.color(
              node.string("check_color") ?? ChipPresentation.checkmarkColorToken(node)))
      } else if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
          .modifier(ChipSlotConstraints(value: node.props["leading_size_constraints"]))
      }
      label
        .foregroundColor(MaterialPalette.color(ChipPresentation.labelColorToken(node)))
        .padding(
          ControlProps.edgeInsets(node.props["label_padding"])
            ?? EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
      if node.handlesEvent("delete") {
        Button {
          events.fire(node, "delete")
        } label: {
          deleteIcon
        }
        .buttonStyle(.plain)
        .disabled(node.bool("disabled") == true)
        .help(ChipPresentation.deleteTooltip(node) ?? "")
        .modifier(ChipSlotConstraints(value: node.props["delete_icon_size_constraints"]))
      }
    }
    .padding(
      ControlProps.edgeInsets(node.props["padding"])
        ?? EdgeInsets(
          top: ChipPresentation.defaultPadding,
          leading: ChipPresentation.defaultPadding,
          bottom: ChipPresentation.defaultPadding,
          trailing: ChipPresentation.defaultPadding)
    )
    .modifier(VisualDensityPadding(value: node.props["visual_density"]))
    .background(shape.fill(fill))
    .overlay(shape.strokeBorder(borderColor, lineWidth: borderWidth))
    .shadow(color: shadowColor, radius: elevation)
    .contentShape(shape)
    .modifier(ChromeClipModifier(behavior: node.string("clip_behavior") ?? "none"))
    .animation(rufletAnimation(node.props["select_animation_style"]), value: selected)
    .animation(slotAnimation, value: node.props["leading"] != nil)
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in pressed = true }
        .onEnded { _ in pressed = false }
    )
    .onTapGesture {
      guard node.bool("disabled") != true else { return }
      // InputChip rejects this combination; prefer neither event over
      // silently choosing one and diverging from the Flet validation path.
      guard !(node.handlesEvent("select") && node.handlesEvent("click")) else { return }
      if node.handlesEvent("select") {
        events.commit(node, key: "selected", value: .bool(!selected), event: "select")
      } else if node.handlesEvent("click") {
        events.fire(node, "click")
      }
    }
    .modifier(FocusReporter(node: node, events: events))
  }

  @ViewBuilder
  private var label: some View {
    if let labelID = node.controlID(forKey: "label") {
      ControlView(id: labelID, axis: .none)
    } else if let label = node.string("label") {
      Text(label)
        .rufletTextStyle(RufletTextStyle(node: node, styleKey: "label_text_style"))
    }
  }

  @ViewBuilder
  private var deleteIcon: some View {
    if node.props["delete_icon"] != nil {
      RufletIcon(
        value: node.props["delete_icon"], size: ChipPresentation.defaultIconSize,
        color: MaterialPalette.color(
          node.string("delete_icon_color") ?? ChipPresentation.deleteIconColorToken(node)))
    } else {
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: ChipPresentation.defaultIconSize))
        .foregroundColor(
          MaterialPalette.color(
            node.string("delete_icon_color") ?? ChipPresentation.deleteIconColorToken(node)))
    }
  }

  /// `shape` is Flutter's `OutlinedBorder`; a chip is a capsule unless a
  /// corner radius says otherwise.
  private var shape: ChipShape {
    ChipShape(
      radius: ControlProps.cornerRadius(node.map("shape")?["radius"])
        ?? ChipPresentation.defaultCornerRadius)
  }

  private var fill: Color {
    let states = node.widgetStates(
      selected: node.bool("selected"), extra: pressed ? [.pressed] : [])
    if let stateColor = MaterialPalette.color(stateful: node.props["color"], in: states) {
      return stateColor
    }
    if node.bool("disabled") == true {
      let fallback = node.bool("selected") == true ? "onsurface,0.12" : nil
      return MaterialPalette.color(node.string("disabled_color") ?? fallback, default: .clear)
    }
    let selected = node.bool("selected") ?? false
    if selected {
      return MaterialPalette.color(
        node.string("selected_color") ?? ChipPresentation.selectedColorToken,
        default: .clear)
    }
    return MaterialPalette.color(node.string("bgcolor"), default: .clear)
  }

  private var borderColor: Color {
    if let side = node.map("border_side"), let color = side["color"]?.stringValue {
      return MaterialPalette.color(color, default: .clear)
    }
    return MaterialPalette.color(
      ChipPresentation.borderColorToken(node), default: .clear)
  }

  private var borderWidth: CGFloat {
    if let side = node.map("border_side"), let width = side["width"]?.doubleValue {
      return CGFloat(width)
    }
    return (node.bool("selected") ?? false) ? 0 : 1
  }

  private var shadowColor: Color {
    let resting = MaterialPalette.color(node.string("shadow_color"), default: .black.opacity(0.2))
    guard node.bool("selected") ?? false else { return resting }
    return MaterialPalette.color(node.string("selected_shadow_color"), default: resting)
  }

  /// `elevation_on_click` is Material's pressed elevation; a chip that names
  /// one lifts while the pointer is down.
  private var elevation: CGFloat {
    let resting = node.double("elevation") ?? 0
    guard pressed, let raised = node.double("elevation_on_click") else { return CGFloat(resting) }
    return CGFloat(raised)
  }

  /// The drawer animations Flutter runs when the leading or delete icon
  /// appears; both are duration-carrying AnimationStyles like the selection.
  private var slotAnimation: Animation? {
    rufletAnimation(
      node.props["leading_drawer_animation_style"]
        ?? node.props["delete_drawer_animation_style"]
        ?? node.props["enable_animation_style"])
  }
}

enum ChipPresentation {
  static let defaultCornerRadius: CGFloat = 8
  static let defaultPadding: CGFloat = 8
  static let defaultIconSize: CGFloat = 18
  static let selectedColorToken = "secondarycontainer"

  /// Visual values are the boundary between a native Apple chip equivalent
  /// and Flet's explicitly requested Material rendering. Content, state and
  /// event properties do not opt out of the native control family.
  static func requiresCustomRendering(_ node: ControlNode) -> Bool {
    let visualKeys = [
      "bgcolor", "color", "disabled_color", "selected_color", "check_color",
      "delete_icon_color", "border_side", "shape", "padding", "label_padding",
      "elevation", "elevation_on_click", "shadow_color", "selected_shadow_color",
      "visual_density", "clip_behavior", "select_animation_style",
      "leading_drawer_animation_style", "delete_drawer_animation_style",
      "enable_animation_style", "label_text_style",
    ]
    return visualKeys.contains { node.props[$0] != nil || node.internals[$0] != nil }
  }

  static func validationMessage(_ node: ControlNode) -> String? {
    let hasLabel =
      node.controlID(forKey: "label") != nil
      || !(node.string("label") ?? "").isEmpty
    if !hasLabel { return "Chip.label must be provided and visible" }
    if node.handlesEvent("select") && node.handlesEvent("click") {
      return "Chip cannot have both on_select and on_click events specified"
    }
    return nil
  }

  static func labelColorToken(_ node: ControlNode) -> String {
    if node.bool("disabled") == true { return "onsurface" }
    return node.bool("selected") == true ? "onsecondarycontainer" : "onsurfacevariant"
  }

  static func checkmarkColorToken(_ node: ControlNode) -> String {
    if node.bool("disabled") == true { return "onsurface" }
    return node.bool("selected") == true ? "primary" : "onsurfacevariant"
  }

  static func deleteIconColorToken(_ node: ControlNode) -> String {
    if node.bool("disabled") == true { return "onsurface" }
    return node.bool("selected") == true ? "onsecondarycontainer" : "onsurfacevariant"
  }

  static func borderColorToken(_ node: ControlNode) -> String {
    if node.bool("selected") == true { return "transparent" }
    return node.bool("disabled") == true ? "onsurface,0.12" : "outlinevariant"
  }

  /// Pinned Flet calls this `delete_button_tooltip`; Ruflet's public DSL has
  /// historically serialized the equivalent field as `delete_icon_tooltip`.
  /// Resolve both at the control boundary so the native constructor retains
  /// Flet semantics without making applications rewrite their DSL.
  static func deleteTooltip(_ node: ControlNode) -> String? {
    node.string("delete_icon_tooltip") ?? node.string("delete_button_tooltip")
  }
}

private struct NativeChipButtonStyle: ViewModifier {
  let selected: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if selected {
      content.buttonStyle(.borderedProminent)
    } else {
      content.buttonStyle(.bordered)
    }
  }
}

/// A capsule unless Ruby gave a corner radius. Insettable so `strokeBorder`
/// draws inside the edge; `AnyShape` would have done but it is iOS 16.
struct ChipShape: InsettableShape {
  let radius: CGFloat?
  var inset: CGFloat = 0

  func path(in rect: CGRect) -> Path {
    let bounds = rect.insetBy(dx: inset, dy: inset)
    let corner = radius ?? min(bounds.width, bounds.height) / 2
    return RoundedRectangle(cornerRadius: corner).path(in: bounds)
  }

  func inset(by amount: CGFloat) -> ChipShape {
    ChipShape(radius: radius, inset: inset + amount)
  }
}

/// Flutter's `AnimationStyle`, which carries a duration in milliseconds.
func rufletAnimation(_ value: RufletValue?) -> Animation? {
  guard let map = value?.mapValue else { return .default }
  guard let duration = map["duration"]?.doubleValue else { return .default }
  return RufletCurve.animation(map["curve"]?.stringValue, duration: duration / 1_000)
}

/// Flutter's `VisualDensity` shifts a control's padding on both axes; the
/// units are logical pixels per step.
struct VisualDensityPadding: ViewModifier {
  let value: RufletValue?

  func body(content: Content) -> some View {
    guard let map = value?.mapValue else { return AnyView(content) }
    let horizontal = CGFloat(map["horizontal"]?.doubleValue ?? 0) * 2
    let vertical = CGFloat(map["vertical"]?.doubleValue ?? 0) * 2
    return AnyView(content.padding(.horizontal, horizontal).padding(.vertical, vertical))
  }
}

private struct ChipSlotConstraints: ViewModifier {
  let value: RufletValue?

  func body(content: Content) -> some View {
    if let constraints = ControlProps.sizeConstraints(value) {
      content.frame(
        minWidth: constraints.minWidth, maxWidth: constraints.maxWidth,
        minHeight: constraints.minHeight, maxHeight: constraints.maxHeight)
    } else {
      content
    }
  }
}

/// `SegmentedButton` — Apple's segmented picker for the ordinary single
/// selection contract, with native button groups for Flet's multi/empty and
/// vertical extensions. Explicit visual styles retain the Material path.
struct SegmentedButtonControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  @ViewBuilder
  var body: some View {
    let segments = node.controlIDs(forKey: "segments").compactMap { store.node($0) }
    let selected = selectedValues
    if let message = SegmentedButtonPresentation.validationMessage(
      segmentCount: segments.count, selected: selectedValuesInWireOrder, node: node)
    {
      Text(message).font(.caption).foregroundStyle(.red)
    } else {
      switch SegmentedButtonPresentation(node: node).route {
      case .picker:
        nativePicker(segments: segments)
      case .buttonGroup:
        nativeButtonGroup(segments: segments, selected: selected)
      case .custom:
        materialButtonGroup(segments: segments, selected: selected)
      }
    }
  }

  private func nativePicker(segments: [ControlNode]) -> some View {
    Picker("", selection: nativeSingleSelection) {
      ForEach(segments, id: \.id) { segment in
        let value = segment.string("value") ?? ""
        segmentLabel(segment, chosen: selectedValues.contains(value))
          .tag(value)
          .disabled(segment.bool("disabled") == true)
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .disabled(node.bool("disabled") == true)
    .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets())
  }

  private var nativeSingleSelection: Binding<String> {
    Binding(
      get: { selectedValuesInWireOrder.first ?? "" },
      set: { value in
        guard value != selectedValuesInWireOrder.first else { return }
        events.commit(
          node, key: "selected", value: .array([.string(value)]), event: "change")
      })
  }

  @ViewBuilder
  private func nativeButtonGroup(segments: [ControlNode], selected: Set<String>) -> some View {
    stack(spacing: nil) {
      ForEach(segments, id: \.id) { segment in
        let value = segment.string("value") ?? ""
        let isSelected = selected.contains(value)
        Button {
          toggle(value: value, selected: selected)
        } label: {
          segmentLabel(segment, chosen: isSelected)
        }
        .modifier(NativeSegmentButtonStyle(selected: isSelected))
        .disabled(node.bool("disabled") == true || segment.bool("disabled") == true)
        .help(segment.bool("disabled") == true ? "" : (segment.string("tooltip") ?? ""))
      }
    }
    .disabled(node.bool("disabled") ?? false)
    .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets())
  }

  @ViewBuilder
  private func materialButtonGroup(segments: [ControlNode], selected: Set<String>) -> some View {
    stack(spacing: 0) {
      ForEach(segments, id: \.id) { segment in
        let value = segment.string("value") ?? ""
        let isSelected = selected.contains(value)
        Button {
          toggle(value: value, selected: selected)
        } label: {
          segmentLabel(segment, chosen: isSelected)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .foregroundColor(
              SegmentedButtonPresentation(node: node).foreground(
                selected: isSelected, disabled: segment.bool("disabled") == true)
            )
            .background(SegmentedButtonPresentation(node: node).background(selected: isSelected))
        }
        .buttonStyle(.plain)
        .disabled(node.bool("disabled") == true || segment.bool("disabled") == true)
        .help(segment.bool("disabled") == true ? "" : (segment.string("tooltip") ?? ""))
      }
    }
    .background(Capsule().fill(Color.clear))
    .overlay(Capsule().strokeBorder(SegmentedButtonPresentation(node: node).border))
    .disabled(node.bool("disabled") ?? false)
    .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets())
  }

  @ViewBuilder
  private func segmentLabel(_ segment: ControlNode, chosen: Bool) -> some View {
    HStack(spacing: 6) {
      // `show_selected_icon` puts a tick — or `selected_icon` — before the
      // label of a chosen segment, the way Material's does.
      if chosen, node.bool("show_selected_icon") != false {
        if let iconID = node.controlID(forKey: "selected_icon") {
          ControlView(id: iconID, axis: .none)
        } else if node.props["selected_icon"] != nil {
          RufletIcon(value: node.props["selected_icon"], size: 14, color: nil)
        } else {
          Image(systemName: "checkmark").font(.caption)
        }
      } else if let iconID = segment.controlID(forKey: "icon") {
        ControlView(id: iconID, axis: .none)
      } else if segment.props["icon"] != nil {
        RufletIcon(value: segment.props["icon"], size: 16, color: nil)
      }
      if let labelID = segment.controlID(forKey: "label") {
        ControlView(id: labelID, axis: .none)
      } else {
        Text(segment.string("label") ?? segment.string("value") ?? "")
      }
    }
  }

  /// `direction` lays the segments out in a row or a column.
  @ViewBuilder
  private func stack<Content: View>(
    spacing: CGFloat?, @ViewBuilder content: () -> Content
  ) -> some View {
    if node.string("direction")?.lowercased() == "vertical" {
      VStack(spacing: spacing) { content() }
    } else {
      HStack(spacing: spacing) { content() }
    }
  }

  private var selectedValues: Set<String> {
    Set(selectedValuesInWireOrder)
  }

  private var selectedValuesInWireOrder: [String] {
    (node.array("selected") ?? []).compactMap(\.stringValue)
  }

  /// `allow_multiple_selection` decides whether a tap adds to or replaces the
  /// selection, matching Flet's SegmentedButton.
  private func toggle(value: String, selected: Set<String>) {
    var next = selected
    if node.bool("allow_multiple_selection") == true {
      if next.contains(value) {
        guard node.bool("allow_empty_selection") != false || next.count > 1 else { return }
        next.remove(value)
      } else {
        next.insert(value)
      }
    } else {
      if next.contains(value), node.bool("allow_empty_selection") == true {
        next.removeAll()
      } else {
        next = [value]
      }
    }
    let retained = selectedValuesInWireOrder.filter(next.contains)
    let appended = next.filter { !retained.contains($0) }
    let payload = RufletValue.array((retained + appended).map(RufletValue.string))
    events.commit(node, key: "selected", value: payload, event: "change")
  }
}

struct SegmentedButtonPresentation {
  let node: ControlNode

  private var style: [String: RufletValue]? {
    node.internals["style"]?.mapValue ?? node.props["style"]?.mapValue
  }

  enum Route: Equatable {
    case picker
    case buttonGroup
    case custom
  }

  var route: Route {
    if requiresCustomRendering { return .custom }
    if node.bool("allow_multiple_selection") == true
      || node.bool("allow_empty_selection") == true
      || node.string("direction")?.lowercased() == "vertical"
    {
      return .buttonGroup
    }
    return .picker
  }

  private var requiresCustomRendering: Bool {
    guard let style else { return false }
    return !style.isEmpty
  }

  static func validationMessage(
    segmentCount: Int, selected: [String], node: ControlNode
  ) -> String? {
    if segmentCount == 0 {
      return "SegmentedButton.segments must be contain at least one visible segment"
    }
    let allowEmpty = node.bool("allow_empty_selection") == true
    let multiple = node.bool("allow_multiple_selection") == true
    if selected.isEmpty && !allowEmpty {
      return
        "SegmentedButton.selected must contain at least one value because allow_empty_selection=False"
    }
    if !multiple && selected.count != 1 && !allowEmpty {
      return
        "SegmentedButton.selected must contain exactly one value because allow_multiple_selection=False"
    }
    if multiple && selected.count > segmentCount {
      return
        "The length of SegmentedButton.selected must be less than or equal to the number of visible segments"
    }
    return nil
  }

  func foreground(selected: Bool, disabled: Bool) -> Color {
    if let value = style?["color"] {
      var states: Set<RufletWidgetState> = selected ? [.selected] : []
      if disabled || node.bool("disabled") == true { states.insert(.disabled) }
      return MaterialPalette.color(stateful: value, in: states) ?? .primary
    }
    if disabled || node.bool("disabled") == true {
      return MaterialPalette.color("onsurface,0.38", default: .primary)
    }
    return MaterialPalette.color(selected ? "onsecondarycontainer" : "onsurface", default: .primary)
  }

  func background(selected: Bool) -> Color {
    if let value = style?["bgcolor"] {
      return MaterialPalette.color(stateful: value, in: selected ? [.selected] : []) ?? .clear
    }
    return MaterialPalette.color(selected ? "secondarycontainer" : "transparent", default: .clear)
  }

  var border: Color {
    if let side = style?["side"]?.mapValue {
      return MaterialPalette.color(side["color"]?.stringValue, default: .clear)
    }
    return MaterialPalette.color(
      node.bool("disabled") == true ? "onsurface,0.12" : "outline", default: .clear)
  }
}

private struct NativeSegmentButtonStyle: ViewModifier {
  let selected: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if selected {
      content.buttonStyle(.borderedProminent)
    } else {
      content.buttonStyle(.bordered)
    }
  }
}
