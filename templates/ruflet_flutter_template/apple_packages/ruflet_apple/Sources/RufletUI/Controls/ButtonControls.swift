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
  case floatingAction

  init(wireType: String) {
    switch wireType {
    case "FilledButton": self = .filled
    case "FilledTonalButton": self = .filledTonal
    case "OutlinedButton": self = .outlined
    case "TextButton": self = .text
    case "IconButton", "FilledIconButton", "FilledTonalIconButton", "OutlinedIconButton":
      self = .icon
    case "FloatingActionButton": self = .floatingAction
    default: self = .elevated
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

  @ViewBuilder
  private var label: some View {
    let icon = node.props["icon"]

    if variant == .icon || variant == .floatingAction {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else if icon != nil {
        RufletIcon(
          value: icon,
          size: node.double("icon_size").map { CGFloat($0) }
            ?? RufletThemeDefaults.materialIconButtonSize,
          color: MaterialPalette.color(node.string("icon_color")))
      } else if let caption = captionText {
        Text(caption)
      }
    } else {
      HStack(spacing: RufletThemeDefaults.materialButtonIconSpacing) {
        if icon != nil {
          RufletIcon(
            value: icon,
            size: node.double("icon_size").map { CGFloat($0) }
              ?? RufletThemeDefaults.materialIconButtonSize,
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
      // Flet passes nil colours to FloatingActionButton, so native/theme
      // defaults must remain in charge unless Ruby supplied one explicitly.
      content()
        .buttonStyle(.borderedProminent)
        .modifier(OptionalTint(color: MaterialPalette.color(node.string("bgcolor"))))
        .modifier(OptionalForeground(color: MaterialPalette.color(node.string("color"))))
    case .icon:
      content()
        .buttonStyle(.borderless)
        .modifier(OptionalTint(color: foreground))
        .modifier(OptionalForeground(color: foreground))
    }
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
  return .easeInOut(duration: duration / 1_000)
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

    HStack(spacing: 0) {
      ForEach(segments, id: \.id) { segment in
        let value = segment.string("value") ?? ""
        Button {
          toggle(value: value, selected: selected)
        } label: {
          segmentLabel(segment)
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
  private func segmentLabel(_ segment: ControlNode) -> some View {
    if let labelID = segment.controlID(forKey: "label") {
      ControlView(id: labelID, axis: .none)
    } else {
      Text(segment.string("label") ?? segment.string("value") ?? "")
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
