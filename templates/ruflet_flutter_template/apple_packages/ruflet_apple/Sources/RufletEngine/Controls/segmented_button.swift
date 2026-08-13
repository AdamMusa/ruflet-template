import RufletProtocol
import SwiftUI

/// Apple-native port of pinned Flet `SegmentedButtonControl`.
@MainActor
public struct SegmentedButtonControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var coordinator: RufletSegmentSelectionCoordinator

  public init(control: RufletControl) {
    self.control = control
    _coordinator = StateObject(wrappedValue: RufletSegmentSelectionCoordinator(control: control))
  }

  public var body: some View {
    LayoutControl(control: control) {
      if segments.isEmpty {
        ErrorControl("SegmentedButton.segments must be contain at least one visible segment")
      } else if coordinator.selected.isEmpty && !coordinator.allowEmpty {
        ErrorControl("SegmentedButton.selected must contain at least one value because allow_empty_selection=False")
      } else if !coordinator.allowsMultiple
                  && coordinator.selected.count != 1
                  && !coordinator.allowEmpty {
        ErrorControl("SegmentedButton.selected must contain exactly one value because allow_multiple_selection=False")
      } else if coordinator.allowsMultiple && coordinator.selected.count > segments.count {
        ErrorControl("The length of SegmentedButton.selected must be less than or equal to the number of visible segments")
      } else {
        segmentLayout
          .padding(parsePadding(control.dynamicValue("padding")) ?? EdgeInsets())
      }
    }
    .onAppear { coordinator.synchronizeFromControl() }
    .onChange(of: control.properties) { _ in coordinator.synchronizeFromControl() }
  }

  @ViewBuilder
  private var segmentLayout: some View {
    if vertical {
      VStack(spacing: 0) { segmentButtons }
    } else {
      HStack(spacing: 0) { segmentButtons }
    }
  }

  @ViewBuilder
  private var segmentButtons: some View {
    ForEach(Array(segments.enumerated()), id: \.element.value) { index, segment in
      RufletSegmentButton(
        selected: coordinator.selected.contains(segment.value),
        enabled: !control.disabled && !segment.control.disabled,
        showSelectedIcon: control.boolean("show_selected_icon", default: true),
        selectedIcon: control.buildIconOrWidget("selected_icon"),
        icon: segment.control.buildIconOrWidget("icon"),
        label: segment.control.buildTextOrWidget("label"),
        style: segmentStyle,
        first: index == 0,
        last: index == segments.count - 1,
        vertical: vertical,
        action: { coordinator.toggle(segment.value, orderedValues: segments.map(\.value)) })
        .help(segment.control.disabled ? "" : segment.control.string("tooltip", default: "") ?? "")
    }
  }

  private var segments: [RufletSegment] {
    control.children("segments").compactMap { segment in
      segment.notifyParent = true
      guard let value = segment.string("value") else { return nil }
      return RufletSegment(control: segment, value: value)
    }
  }

  private var vertical: Bool {
    control.string("direction", default: "horizontal")?.lowercased() == "vertical"
  }

  private var segmentStyle: RufletSegmentStyle {
    let details = rufletDictionary(control.internals?["style"].map(rufletAny)
      ?? control.dynamicValue("style"))
    return RufletSegmentStyle(
      foreground: parseColor(details?["color"] as? String) ?? .accentColor,
      background: parseColor(details?["bgcolor"] as? String) ?? .rufletSegmentSurface,
      selectedForeground: parseColor(details?["selected_color"] as? String) ?? .white,
      selectedBackground: parseColor(details?["selected_bgcolor"] as? String) ?? .accentColor,
      border: parseColor(rufletDictionary(details?["side"])?["color"] as? String) ?? .accentColor,
      radius: parseBorderRadius(details?["shape"])?.uniform ?? 8)
  }
}

struct RufletSegment {
  let control: RufletControl
  let value: String
}

@MainActor
final class RufletSegmentSelectionCoordinator: ObservableObject {
  @Published private(set) var selected: [String]
  let control: RufletControl

  init(control: RufletControl) {
    self.control = control
    selected = Self.readSelection(control)
  }

  var allowEmpty: Bool { control.boolean("allow_empty_selection", default: false) }
  var allowsMultiple: Bool { control.boolean("allow_multiple_selection", default: false) }

  func synchronizeFromControl() {
    let next = Self.readSelection(control)
    if selected != next { selected = next }
  }

  func toggle(_ value: String, orderedValues: [String]) {
    guard !control.disabled else { return }
    var next = Set(selected)
    if allowsMultiple {
      if next.contains(value) {
        if allowEmpty || next.count > 1 { next.remove(value) }
      } else {
        next.insert(value)
      }
    } else if next.contains(value) && allowEmpty {
      next.removeAll()
    } else {
      next = [value]
    }
    let ordered = orderedValues.filter(next.contains)
    guard ordered != selected else { return }
    selected = ordered
    let wire = RufletValue.array(ordered.map(RufletValue.string))
    control.updateProperties(["selected": wire], notify: true)
    control.triggerEvent("change", data: wire)
  }

  private static func readSelection(_ control: RufletControl) -> [String] {
    control.value("selected")?.array?.compactMap { value in
      value.text ?? value.integer.map { String($0) } ?? value.number.map { String($0) }
    } ?? []
  }
}

struct RufletSegmentStyle {
  let foreground: Color
  let background: Color
  let selectedForeground: Color
  let selectedBackground: Color
  let border: Color
  let radius: CGFloat
}

private struct RufletSegmentButton: View {
  let selected: Bool
  let enabled: Bool
  let showSelectedIcon: Bool
  let selectedIcon: AnyView?
  let icon: AnyView?
  let label: AnyView?
  let style: RufletSegmentStyle
  let first: Bool
  let last: Bool
  let vertical: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if selected && showSelectedIcon {
          if let selectedIcon { selectedIcon } else { Image(systemName: "checkmark") }
        } else if let icon {
          icon
        }
        label
      }
      .frame(maxWidth: .infinity, minHeight: 32)
      .padding(.horizontal, 9)
      .padding(.vertical, 4)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(selected ? style.selectedForeground : style.foreground)
    .background(selected ? style.selectedBackground : style.background)
    .overlay { Rectangle().stroke(style.border, lineWidth: 0.75) }
    .clipShape(RufletSegmentClipShape(
      radius: style.radius, first: first, last: last, vertical: vertical))
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.45)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

private struct RufletSegmentClipShape: Shape {
  let radius: CGFloat
  let first: Bool
  let last: Bool
  let vertical: Bool

  func path(in rect: CGRect) -> Path {
    let firstRadius = first ? radius : 0
    let lastRadius = last ? radius : 0
    return RufletCornerShape(radius: vertical
      ? RufletBorderRadius(
        topLeft: firstRadius, topRight: firstRadius,
        bottomLeft: lastRadius, bottomRight: lastRadius)
      : RufletBorderRadius(
        topLeft: firstRadius, topRight: lastRadius,
        bottomLeft: firstRadius, bottomRight: lastRadius))
      .path(in: rect)
  }
}

private extension Color {
  static var rufletSegmentSurface: Color {
    #if os(iOS)
    Color(uiColor: .secondarySystemBackground)
    #else
    Color(nsColor: .controlBackgroundColor)
    #endif
  }
}
