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
            ?? FletThemeDefaults.materialIconButtonSize,
          color: MaterialPalette.color(node.string("icon_color")))
      } else if let caption = captionText {
        Text(caption)
      }
    } else {
      HStack(spacing: FletThemeDefaults.materialButtonIconSpacing) {
        if icon != nil {
          RufletIcon(
            value: icon,
            size: node.double("icon_size").map { CGFloat($0) }
              ?? FletThemeDefaults.materialIconButtonSize,
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
          FletMaterialButtonStyle(
            foreground: foreground,
            background: fill,
            overlay: MaterialPalette.color(for: node, property: "overlay_color"),
            shadow: MaterialPalette.color(for: node, property: "shadow_color"),
            elevation: node.double("elevation") ?? FletThemeDefaults.materialButtonElevation))
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
private struct FletMaterialButtonStyle: ButtonStyle {
  let foreground: Color?
  let background: Color?
  let overlay: Color?
  let shadow: Color?
  let elevation: Double

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(FletThemeDefaults.materialButtonPadding)
      .frame(minHeight: FletThemeDefaults.minimumInteractiveDimension)
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

  var body: some View {
    let selected = node.bool("selected") ?? false

    HStack(spacing: 6) {
      if node.props["leading"] != nil {
        RufletIcon(value: node.props["leading"], size: 16, color: nil)
      }
      if let labelID = node.controlID(forKey: "label") {
        ControlView(id: labelID, axis: .none)
      } else if let label = node.string("label") {
        Text(label).font(.subheadline)
      }
      if node.handlesEvent("delete") {
        Button {
          events.fire(node, "delete")
        } label: {
          Image(systemName: "xmark.circle.fill").font(.caption)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(
      Capsule().fill(
        selected
          ? MaterialPalette.color(for: node, property: "selected_color", default: .clear)
          : MaterialPalette.color(node.string("bgcolor"), default: .clear)))
    .overlay(
      Capsule().strokeBorder(
        MaterialPalette.color(for: node, property: "border_color", default: .clear),
        lineWidth: selected ? 0 : 1))
    .contentShape(Capsule())
    .onTapGesture {
      guard node.bool("disabled") != true else { return }
      if node.handlesEvent("select") {
        events.commit(node, key: "selected", value: .bool(!selected), event: "select")
      } else {
        events.fire(node, "click")
      }
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
