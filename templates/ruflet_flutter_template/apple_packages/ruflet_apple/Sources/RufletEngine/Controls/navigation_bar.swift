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
  @Environment(\.rufletPageTheme) private var pageTheme
  let kind: Kind

  init(control: RufletControl, kind: Kind) {
    self.control = control
    self.kind = kind
    _selectedIndex = State(initialValue: control.integer("selected_index", default: 0) ?? 0)
  }

  var body: some View {
    let presentation = RufletNavigationBarPresentation(
      control: control,
      theme: pageTheme,
      isCupertino: kind == .cupertino)
    LayoutControl(control: control) {
      HStack(spacing: 0) {
        ForEach(Array(destinations.enumerated()), id: \.element.id) { index, destination in
          destinationButton(destination, index: index, presentation: presentation)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: presentation.height)
      .background(presentation.backgroundColor.background(.bar))
      .overlay(alignment: .top) { border }
      .shadow(
        color: presentation.shadowColor.opacity(presentation.elevation > 0 ? 0.18 : 0),
        radius: presentation.elevation,
        y: -presentation.elevation / 2
      )
      .animation(presentation.selectionAnimation, value: selectedIndex)
    }
    .onAppear(perform: synchronizeFromControl)
    .onChange(of: control.properties) { _ in synchronizeFromControl() }
  }

  private func destinationButton(
    _ destination: RufletControl,
    index: Int,
    presentation: RufletNavigationBarPresentation
  ) -> some View {
    let selected = selectedIndex == index
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
        .frame(height: presentation.iconSize)
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
        .background {
          if kind == .navigationBar, selected {
            RufletNavigationIndicatorShape(description: presentation.indicatorShape)
              .fill(presentation.indicatorColor)
          }
        }

        if presentation.labelBehavior.showsLabel(selected: selected),
          let label = destination.string("label"), !label.isEmpty
        {
          Text(label)
            .modifier(RufletTextStyleModifier(style: presentation.labelTextStyle.resolve(states)))
            .environment(\.rufletInheritsTextColor, true)
            .font(.caption2)
            .lineLimit(1)
            .padding(presentation.labelPadding)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      .foregroundStyle(
        selected ? presentation.selectedForegroundColor : presentation.unselectedForegroundColor)
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

}

struct RufletNavigationBarPresentation {
  let backgroundColor: Color
  let shadowColor: Color
  let indicatorColor: Color
  let indicatorShape: RufletNavigationIndicatorShapeDescription
  let overlayColor: RufletWidgetStateProperty<Color>
  let labelTextStyle: RufletWidgetStateProperty<RufletTextStyle>
  let labelBehavior: RufletNavigationLabelBehavior
  let labelPadding: EdgeInsets
  let selectedForegroundColor: Color
  let unselectedForegroundColor: Color
  let elevation: CGFloat
  let height: CGFloat
  let iconSize: CGFloat
  let selectionAnimation: Animation?

  @MainActor
  init(
    control: RufletControl,
    theme: RufletTheme? = nil,
    isCupertino: Bool = false,
    nativeDefaultHeight: Double = 50
  ) {
    let componentTheme = theme?.componentTheme("navigation_bar_theme")
    backgroundColor =
      parseColor(control.string("bgcolor"))
      ?? rufletNavigationBarColor(componentTheme?["bgcolor"])
      ?? theme?.colorScheme?["surface_container"]
      ?? Color.rufletSystemBackground
    shadowColor =
      parseColor(control.string("shadow_color"))
      ?? rufletNavigationBarColor(componentTheme?["shadow_color"])
      ?? theme?.colorScheme?["shadow"]
      ?? .black
    indicatorColor =
      parseColor(control.string("indicator_color"))
      ?? rufletNavigationBarColor(componentTheme?["indicator_color"])
      ?? theme?.colorScheme?["secondary_container"]
      ?? Color.accentColor.opacity(0.16)
    indicatorShape = RufletNavigationIndicatorShapeDescription(
      control.dynamicValue("indicator_shape") ?? componentTheme?["indicator_shape"])
    overlayColor = RufletWidgetStateProperty(
      control.dynamicValue("overlay_color") ?? componentTheme?["overlay_color"],
      converter: rufletNavigationBarColor)
    labelTextStyle = RufletWidgetStateProperty(
      componentTheme?["label_text_style"],
      converter: { parseTextStyle($0) })
    labelBehavior = isCupertino
      ? .alwaysShow
      : .wire(
        control.string("label_behavior")
          ?? rufletNavigationBarString(componentTheme?["label_behavior"]))
    labelPadding = isCupertino
      ? EdgeInsets()
      : parsePadding(control.dynamicValue("label_padding"))
        ?? parsePadding(componentTheme?["label_padding"])
        ?? RufletLayoutDefaults.navigationBarLabel
    if isCupertino {
      selectedForegroundColor =
        parseColor(control.string("active_color"))
        ?? parseColor(control.string("indicator_color"))
        ?? theme?.appleAccentColor
        ?? .accentColor
      unselectedForegroundColor =
        parseColor(control.string("inactive_color"))
        ?? .secondary
      elevation = 0
    } else {
      selectedForegroundColor =
        theme?.colorScheme?["on_secondary_container"]
        ?? theme?.appleContentColor
        ?? .primary
      unselectedForegroundColor =
        theme?.colorScheme?["on_surface_variant"]
        ?? theme?.appleContentColor
        ?? .secondary
      elevation = CGFloat(max(
        control.number("elevation")
          ?? parseDouble(componentTheme?["elevation"])
          ?? 0,
        0))
    }
    height = CGFloat(max(
      control.number("height")
        ?? parseDouble(componentTheme?["height"])
        ?? nativeDefaultHeight,
      0))
    iconSize = CGFloat(max(
      isCupertino ? control.number("icon_size", default: 30) ?? 30 : 24,
      0))
    let duration = parseDuration(control.dynamicValue("animation_duration"), 0.2)!
    selectionAnimation = duration > 0 ? .easeInOut(duration: duration) : nil
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

private func rufletNavigationBarString(_ raw: Any?) -> String? {
  if let string = raw as? String { return string }
  if let value = raw as? RufletValue { return value.text }
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
