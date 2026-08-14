import RufletProtocol
import SwiftUI

enum RufletNavigationLabelBehavior: String, CaseIterable, RufletStringEnum {
  case alwaysShow
  case alwaysHide
  case onlyShowSelected

  static func wire(_ value: String?) -> Self {
    parseEnum(Self.self, value, .alwaysShow)!
  }

  func showsLabel(selected: Bool) -> Bool {
    switch self {
    case .alwaysShow: true
    case .alwaysHide: false
    case .onlyShowSelected: selected
    }
  }
}

@MainActor
func resolveRufletSelectionIndex(
  _ requested: Int?, count: Int, defaultIndex: Int = 0
) -> Int? {
  guard count > 0 else { return nil }
  let raw = requested ?? defaultIndex
  let resolved = raw < 0 ? count + raw : raw
  return min(max(resolved, 0), count - 1)
}

@MainActor
func rufletCommitSelection(
  control: RufletControl,
  index: Int,
  event: String = "change",
  notify: Bool
) {
  control.updateProperties(
    ["selected_index": .int(Int64(index))],
    notify: notify)
  control.triggerEvent(event, data: .int(Int64(index)))
}

@MainActor
func rufletNavigationChildren(
  _ control: RufletControl, property: String = "destinations"
) -> [RufletControl] {
  control.children(property).map { destination in
    destination.notifyParent = true
    return destination
  }
}

/// Apple-native port of pinned Flet `navigation_bar.dart`.
@MainActor
public struct NavigationBarControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    RufletAppleNavigationBar(
      control: control,
      kind: control.adaptive == true ? .cupertino : .navigationBar)
  }
}

@MainActor
struct RufletAppleNavigationBar: View {
  enum Kind { case navigationBar, cupertino }

  @ObservedObject var control: RufletControl
  @State private var selectedIndex: Int
  @State private var hoveredIndex: Int?
  let kind: Kind

  init(control: RufletControl, kind: Kind) {
    self.control = control
    self.kind = kind
    _selectedIndex = State(initialValue: control.integer("selected_index", default: 0) ?? 0)
  }

  var body: some View {
    LayoutControl(control: control) {
      HStack(spacing: 0) {
        ForEach(Array(destinations.enumerated()), id: \.element.id) { index, destination in
          destinationButton(destination, index: index)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: barHeight)
      .padding(labelPadding)
      .background(background)
      .overlay(alignment: .top) { border }
      .shadow(
        color: (parseColor(control.string("shadow_color")) ?? .black)
          .opacity(elevation > 0 ? 0.18 : 0),
        radius: elevation,
        y: -elevation / 2
      )
      .animation(selectionAnimation, value: selectedIndex)
    }
    .onAppear(perform: synchronizeFromControl)
    .onChange(of: control.properties) { _ in synchronizeFromControl() }
  }

  private func destinationButton(_ destination: RufletControl, index: Int) -> some View {
    let selected = selectedIndex == index
    let presentation = RufletNavigationBarPresentation(control: control)
    let states = presentation.states(
      selected: selected,
      hovered: hoveredIndex == index,
      pressed: false,
      disabled: !destinationIsInteractive(destination))
    return Button {
      guard destinationIsInteractive(destination) else { return }
      selectedIndex = index
      rufletCommitSelection(
        control: control,
        index: index,
        event: "change",
        notify: true)
    } label: {
      VStack(spacing: 2) {
        Group {
          if selected, let selectedIcon = destination.buildIconOrWidget("selected_icon") {
            selectedIcon
          } else if let icon = destination.buildIconOrWidget("icon") {
            icon
          } else {
            EmptyView()
          }
        }
        .frame(height: iconSize)
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
        .background {
          if kind == .navigationBar, selected {
            RufletNavigationIndicatorShape(description: presentation.indicatorShape)
              .fill(presentation.indicatorColor)
          }
        }

        if labelBehavior.showsLabel(selected: selected),
          let label = destination.string("label"), !label.isEmpty
        {
          Text(label)
            .font(.caption2)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      .foregroundStyle(selected ? activeColor : inactiveColor)
      .background(presentation.overlay(states))
    }
    .buttonStyle(
      RufletNavigationBarButtonStyle(
        presentation: presentation,
        selected: selected,
        disabled: !destinationIsInteractive(destination))
    )
    .disabled(!destinationIsInteractive(destination))
    .onHover { hovering in
      hoveredIndex = hovering ? index : (hoveredIndex == index ? nil : hoveredIndex)
    }
    .modifier(
      RufletNavigationTooltip(text: destination.string("tooltip"), enabled: !destination.disabled)
    )
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var destinations: [RufletControl] {
    rufletNavigationChildren(control, property: "destinations")
  }

  private func synchronizeFromControl() {
    guard !destinations.isEmpty else {
      selectedIndex = 0
      return
    }
    precondition(
      destinations.count >= 2,
      "\(control.type) requires at least two visible destinations")
    let requested = control.integer("selected_index", default: 0) ?? 0
    precondition(
      destinations.indices.contains(requested),
      "\(control.type).selected_index must reference a visible destination")
    if selectedIndex != requested { selectedIndex = requested }
  }

  private func destinationIsInteractive(_ destination: RufletControl) -> Bool {
    !control.disabled && (kind == .cupertino || !destination.disabled)
  }

  private var labelBehavior: RufletNavigationLabelBehavior {
    guard kind == .navigationBar else { return .alwaysShow }
    return .wire(control.string("label_behavior"))
  }

  private var activeColor: Color {
    parseColor(control.string("active_color"))
      ?? parseColor(control.string("indicator_color"))
      ?? .accentColor
  }

  private var inactiveColor: Color {
    parseColor(control.string("inactive_color")) ?? .secondary
  }

  private var background: some View {
    (parseColor(control.string("bgcolor")) ?? Color.rufletSystemBackground)
      .background(.bar)
  }

  @ViewBuilder
  private var border: some View {
    if kind == .cupertino, let value = control.dynamicValue("border"),
      let parsed = parseBorder(value)
    {
      RufletBorderOverlay(border: parsed, radius: .zero)
    } else {
      Rectangle().fill(Color.secondary.opacity(0.22)).frame(height: 0.5)
    }
  }

  private var iconSize: CGFloat {
    let value = CGFloat(control.number("icon_size", default: 30) ?? 30)
    precondition(value >= 0, "\(control.type).icon_size must be non-negative")
    return value
  }
  private var barHeight: CGFloat {
    let value = CGFloat(control.number("height", default: 50) ?? 50)
    precondition(value >= 0, "\(control.type).height must be non-negative")
    return value
  }
  private var labelPadding: EdgeInsets {
    kind == .navigationBar
      ? parsePadding(control.dynamicValue("label_padding"))
        ?? RufletLayoutDefaults.navigationBarLabel
      : EdgeInsets()
  }
  private var elevation: CGFloat {
    kind == .navigationBar ? CGFloat(max(control.number("elevation") ?? 0, 0)) : 0
  }
  private var selectionAnimation: Animation? {
    let duration = parseDuration(control.dynamicValue("animation_duration"), 0.2)!
    return duration > 0 ? .easeInOut(duration: duration) : nil
  }
}

struct RufletNavigationBarPresentation {
  let indicatorColor: Color
  let indicatorShape: RufletNavigationIndicatorShapeDescription
  let overlayColor: RufletWidgetStateProperty<Color>

  @MainActor
  init(control: RufletControl) {
    indicatorColor =
      parseColor(control.string("indicator_color"))
      ?? Color.accentColor.opacity(0.16)
    indicatorShape = RufletNavigationIndicatorShapeDescription(
      control.dynamicValue("indicator_shape"))
    overlayColor = RufletWidgetStateProperty(
      control.dynamicValue("overlay_color"),
      converter: rufletNavigationBarColor)
  }

  func states(
    selected: Bool,
    hovered: Bool,
    pressed: Bool,
    disabled: Bool
  ) -> Set<RufletWidgetState> {
    var result = Set<RufletWidgetState>()
    if selected { result.insert(.selected) }
    if hovered { result.insert(.hovered) }
    if pressed { result.insert(.pressed) }
    if disabled { result.insert(.disabled) }
    return result
  }

  func overlay(_ states: Set<RufletWidgetState>) -> Color {
    if let explicit = overlayColor.resolve(states) { return explicit }
    if states.contains(.pressed) { return Color.accentColor.opacity(0.12) }
    if states.contains(.hovered) { return Color.accentColor.opacity(0.07) }
    return .clear
  }
}

enum RufletNavigationIndicatorShapeKind: String, Equatable {
  case circle, stadium, roundedRectangle, beveledRectangle, continuousRectangle
}

struct RufletNavigationIndicatorShapeDescription: Equatable {
  let kind: RufletNavigationIndicatorShapeKind
  let radius: RufletBorderRadius

  init(_ value: Any?) {
    let details = rufletDictionary(value)
    switch (details?["_type"] as? String)?.lowercased() {
    case "circle": kind = .circle
    case "roundedrectangle": kind = .roundedRectangle
    case "beveledrectangle": kind = .beveledRectangle
    case "continuousrectangle": kind = .continuousRectangle
    default: kind = .stadium
    }
    radius = parseBorderRadius(
      details?["radius"] ?? details?["border_radius"],
      RufletBorderRadius(topLeft: 16, topRight: 16, bottomLeft: 16, bottomRight: 16))!
  }
}

private struct RufletNavigationIndicatorShape: Shape {
  let description: RufletNavigationIndicatorShapeDescription

  func path(in rect: CGRect) -> Path {
    switch description.kind {
    case .circle:
      return Path(ellipseIn: rect)
    case .stadium:
      return Capsule().path(in: rect)
    case .roundedRectangle:
      return RufletCornerShape(radius: description.radius).path(in: rect)
    case .continuousRectangle:
      return RoundedRectangle(
        cornerRadius: description.radius.uniform ?? 16,
        style: .continuous
      ).path(in: rect)
    case .beveledRectangle:
      let amount = min(
        CGFloat(description.radius.uniform ?? 16),
        min(rect.width, rect.height) / 2)
      var path = Path()
      path.move(to: CGPoint(x: rect.minX + amount, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX - amount, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + amount))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - amount))
      path.addLine(to: CGPoint(x: rect.maxX - amount, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX + amount, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - amount))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + amount))
      path.closeSubpath()
      return path
    }
  }
}

private struct RufletNavigationBarButtonStyle: ButtonStyle {
  let presentation: RufletNavigationBarPresentation
  let selected: Bool
  let disabled: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label.background(
      presentation.overlay(
        presentation.states(
          selected: selected,
          hovered: false,
          pressed: configuration.isPressed,
          disabled: disabled)))
  }
}

private func rufletNavigationBarColor(_ raw: Any?) -> Color? {
  if let string = raw as? String { return parseColor(string) }
  if let value = raw as? RufletValue { return parseColor(value.text) }
  return nil
}

private struct RufletNavigationTooltip: ViewModifier {
  let text: String?
  let enabled: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled, let text {
      #if os(macOS)
        content.help(text)
      #elseif os(iOS)
        content.accessibilityHint(Text(text))
      #endif
    } else {
      content
    }
  }
}
