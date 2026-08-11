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

  var body: some View {
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

  private var iconSize: CGFloat {
    node.double("icon_size").map { CGFloat($0) } ?? RufletThemeDefaults.materialIconButtonSize
  }

  @ViewBuilder
  private var label: some View {
    let icon = node.props["icon"]

    if variant.isIconButton {
      if icon != nil || node.props["selected_icon"] != nil {
        // A selected icon button swaps both its glyph and its colour, which is
        // what Material's isSelected does.
        RufletIcon(
          value: selected ? (node.props["selected_icon"] ?? icon) : icon,
          size: iconSize,
          color: IconButtonPresentation(node: node).foreground)
      } else if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else if let caption = captionText {
        Text(caption)
      }
    } else if variant == .floatingAction {
      HStack(spacing: RufletThemeDefaults.floatingActionButtonExtendedIconSpacing) {
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
      HStack(spacing: RufletThemeDefaults.materialButtonIconSpacing) {
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

/// Uses Apple's button families and only applies colours when Ruby explicitly
/// supplied them. Omitted values therefore inherit the platform appearance.
private struct NativeButtonPresentation<Content: View>: View {
  let node: ControlNode
  let variant: ButtonVariant
  @ViewBuilder let content: () -> Content

  @ViewBuilder
  var body: some View {
    let fill = MaterialPalette.color(for: node, property: "bgcolor")
    let foreground = MaterialPalette.color(for: node, property: "color")
    switch variant {
    case .filled, .filledTonal, .outlined, .text, .elevated:
      content()
        .buttonStyle(
          RufletMaterialButtonStyle(
            foreground: foreground,
            background: fill,
            overlay: MaterialPalette.color(for: node, property: "overlay_color"),
            shadow: MaterialPalette.color(for: node, property: "shadow_color"),
            elevation: node.double("elevation") ?? RufletThemeDefaults.materialButtonElevation))
    case .floatingAction:
      let geometry = FloatingActionPresentation(node: node)
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
    case .icon, .filledIcon, .filledTonalIcon, .outlinedIcon:
      let presentation = IconButtonPresentation(node: node)
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
    }
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

  static func palette(for node: ControlNode) -> RufletThemeDefaults.IconButtonPalette {
    var palette = RufletThemeDefaults.iconButtonPalette(
      control: node.type,
      selected: node.bool("selected"),
      disabled: node.bool("disabled") == true)
    if node.internals["style"]?.mapValue != nil, node.bool("disabled") != true {
      palette.foreground = RufletThemeDefaults.colorToken(control: node.type, property: "color")
        ?? palette.foreground
    }
    return palette
  }

  private var palette: RufletThemeDefaults.IconButtonPalette { Self.palette(for: node) }

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
      ?? MaterialPalette.color(palette.foreground)
  }

  var background: Color? {
    MaterialPalette.color(node.string("bgcolor")) ?? MaterialPalette.color(palette.background)
  }

  var outline: Color? { MaterialPalette.color(palette.outline) }

  var padding: EdgeInsets {
    ControlProps.edgeInsets(node.props["padding"]) ?? RufletThemeDefaults.materialIconButtonPadding
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
    let side = node.double("splash_radius").map { CGFloat($0) * 2 }
      ?? RufletThemeDefaults.materialIconButtonTargetSize
    return ControlProps.SizeConstraints(minWidth: side, minHeight: side)
  }
}

/// The floating action button's geometry and colours, which Flet names
/// separately from the other button families.
struct FloatingActionPresentation {
  let node: ControlNode

  var isMini: Bool { node.bool("mini") == true }

  /// A FAB carrying both an icon and content is `FloatingActionButton.extended`
  /// — a pill that grows with its label rather than a fixed square.
  var isExtended: Bool { node.props["icon"] != nil && node.props["content"] != nil }

  var side: CGFloat {
    isMini
      ? RufletThemeDefaults.floatingActionButtonMiniSize
      : RufletThemeDefaults.floatingActionButtonSize
  }

  var width: CGFloat? { isExtended ? nil : side }
  var height: CGFloat { side }

  var padding: EdgeInsets {
    isExtended ? RufletThemeDefaults.floatingActionButtonExtendedPadding : EdgeInsets()
  }

  var radius: CGFloat {
    if let explicit = ControlProps.cornerRadius(node.map("shape")?["radius"]) { return explicit }
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
  let foreground: Color?
  let background: Color?
  let overlay: Color?
  let shadow: Color?
  let elevation: Double

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(RufletThemeDefaults.materialButtonPadding)
      .frame(minHeight: RufletThemeDefaults.minimumInteractiveDimension)
      .foregroundColor(foreground)
      .background(background ?? .clear, in: Capsule())
      .overlay {
        if configuration.isPressed {
          Capsule().fill(overlay ?? .clear)
        }
      }
      .shadow(
        color: elevation > 0 ? (shadow ?? .clear) : .clear,
        radius: CGFloat(max(elevation, 0)), y: CGFloat(max(elevation, 0) / 2))
      .contentShape(Capsule())
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
        alignment: alignment)
      .background(Circle().fill(background ?? .clear))
      .background(
        Circle().fill(configuration.isPressed ? (splash ?? .clear) : (highlight ?? .clear)))
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
    let raised = configuration.isPressed
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
        radius: CGFloat(max(raised, 0)), y: CGFloat(max(raised, 0) / 2))
      .onHover { hovering = $0 }
  }
}

/// `enable_feedback` is the platform tap feedback Material plays on a control.
struct TapFeedback: ViewModifier {
  let enabled: Bool

  func body(content: Content) -> some View {
    #if os(iOS)
      if enabled {
        return AnyView(content.simultaneousGesture(
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

  var body: some View {
    let selected = node.bool("selected") ?? false

    HStack(spacing: 6) {
      // A selected chip shows the checkmark in place of its leading icon,
      // which is what Material's `showCheckmark` does.
      if selected, node.bool("show_checkmark") != false {
        Image(systemName: "checkmark")
          .font(.caption)
          .foregroundColor(MaterialPalette.color(node.string("check_color")))
      } else if node.props["leading"] != nil {
        RufletIcon(value: node.props["leading"], size: 16, color: nil)
          .modifier(ChipSlotConstraints(value: node.props["leading_size_constraints"]))
      }
      label
        .padding(ControlProps.edgeInsets(node.props["label_padding"]) ?? EdgeInsets())
      if node.handlesEvent("delete") {
        Button {
          events.fire(node, "delete")
        } label: {
          deleteIcon
        }
        .buttonStyle(.plain)
        .help(node.string("delete_icon_tooltip") ?? "")
        .modifier(ChipSlotConstraints(value: node.props["delete_icon_size_constraints"]))
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .modifier(VisualDensityPadding(value: node.props["visual_density"]))
    .background(shape.fill(fill))
    .overlay(shape.strokeBorder(borderColor, lineWidth: borderWidth))
    .shadow(color: shadowColor, radius: elevation)
    .contentShape(Capsule())
    .animation(rufletAnimation(node.props["select_animation_style"]), value: selected)
    .animation(slotAnimation, value: node.props["leading"] != nil)
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in pressed = true }
        .onEnded { _ in pressed = false })
    .onTapGesture {
      guard node.bool("disabled") != true else { return }
      if node.handlesEvent("select") {
        events.commit(node, key: "selected", value: .bool(!selected), event: "select")
      } else {
        events.fire(node, "click")
      }
    }
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
        value: node.props["delete_icon"], size: 16,
        color: MaterialPalette.color(node.string("delete_icon_color")))
    } else {
      Image(systemName: "xmark.circle.fill")
        .font(.caption)
        .foregroundColor(MaterialPalette.color(node.string("delete_icon_color")))
    }
  }

  /// `shape` is Flutter's `OutlinedBorder`; a chip is a capsule unless a
  /// corner radius says otherwise.
  private var shape: ChipShape {
    ChipShape(radius: ControlProps.cornerRadius(node.map("shape")?["radius"]))
  }

  private var fill: Color {
    if node.bool("disabled") == true {
      return MaterialPalette.color(node.string("disabled_color"), default: .clear)
    }
    let selected = node.bool("selected") ?? false
    return selected
      ? MaterialPalette.color(for: node, property: "selected_color", default: .clear)
      : MaterialPalette.color(node.string("bgcolor"), default: .clear)
  }

  private var borderColor: Color {
    if let side = node.map("border_side"), let color = side["color"]?.stringValue {
      return MaterialPalette.color(color, default: .clear)
    }
    return MaterialPalette.color(for: node, property: "border_color", default: .clear)
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

/// `SegmentedButton` — a Material segmented control, rendered as a picker.
struct SegmentedButtonControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let segments = node.controlIDs(forKey: "segments").compactMap { store.node($0) }
    let selected = selectedValues

    stack(spacing: 0) {
      ForEach(segments, id: \.id) { segment in
        let value = segment.string("value") ?? ""
        Button {
          toggle(value: value, selected: selected)
        } label: {
          segmentLabel(segment, chosen: selected.contains(value))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
              selected.contains(value)
                ? MaterialPalette.color(for: node, property: "selected_color", default: .clear)
                : MaterialPalette.color(for: node, property: "bgcolor", default: .clear))
        }
        .buttonStyle(.plain)
      }
    }
    .background(
      Capsule().fill(MaterialPalette.color(for: node, property: "bgcolor", default: .clear)))
    .overlay(
      Capsule().strokeBorder(
        MaterialPalette.color(for: node, property: "border_color", default: .clear)))
    .disabled(node.bool("disabled") ?? false)
  }

  @ViewBuilder
  private func segmentLabel(_ segment: ControlNode, chosen: Bool) -> some View {
    HStack(spacing: 6) {
      // `show_selected_icon` puts a tick — or `selected_icon` — before the
      // label of a chosen segment, the way Material's does.
      if chosen, node.bool("show_selected_icon") != false {
        if node.props["selected_icon"] != nil {
          RufletIcon(value: node.props["selected_icon"], size: 14, color: nil)
        } else {
          Image(systemName: "checkmark").font(.caption)
        }
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
    spacing: CGFloat, @ViewBuilder content: () -> Content
  ) -> some View {
    if node.string("direction")?.lowercased() == "vertical" {
      VStack(spacing: spacing) { content() }
    } else {
      HStack(spacing: spacing) { content() }
    }
  }

  private var selectedValues: Set<String> {
    Set((node.array("selected") ?? []).compactMap(\.stringValue))
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
      next = [value]
    }
    let payload = RufletValue.array(next.sorted().map(RufletValue.string))
    events.commit(node, key: "selected", value: payload, event: "change")
  }
}
