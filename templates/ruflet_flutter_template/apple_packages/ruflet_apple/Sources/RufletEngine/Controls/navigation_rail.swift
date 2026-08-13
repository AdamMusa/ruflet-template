import RufletProtocol
import SwiftUI

enum RufletNavigationRailLabelType: String, CaseIterable, RufletStringEnum {
  case none
  case selected
  case all
}

/// Apple-native port of pinned Flet `navigation_rail.dart`.
@MainActor
public struct NavigationRailControl: View {
  @ObservedObject public var control: RufletControl
  @State private var selectedIndex: Int?
  @State private var destinationGroupHeight: CGFloat = 0

  public init(control: RufletControl) {
    self.control = control
    _selectedIndex = State(initialValue: control.integer("selected_index"))
  }

  public var body: some View {
    LayoutControl(control: control) {
      VStack(spacing: 8) {
        if let leading = control.buildWidget("leading") {
          leading
        }
        GeometryReader { proxy in
          VStack(spacing: 4) {
            ForEach(Array(destinations.enumerated()), id: \.element.id) { index, destination in
              destinationButton(destination, index: index)
            }
          }
          .fixedSize(horizontal: false, vertical: true)
          .background {
            GeometryReader { group in
              Color.clear.preference(
                key: RufletRailDestinationGroupHeightKey.self,
                value: group.size.height)
            }
          }
          .offset(y: max(proxy.size.height - destinationGroupHeight, 0) * groupFraction)
        }
        if let trailing = control.buildWidget("trailing") {
          trailing
        }
      }
      .frame(minWidth: railWidth, maxHeight: .infinity)
      .padding(.vertical, 8)
      .background(parseColor(control.string("bgcolor")) ?? Color.rufletSystemBackground)
      .shadow(color: .black.opacity(elevation > 0 ? 0.15 : 0), radius: elevation)
    }
    .onAppear(perform: synchronizeFromControl)
    .onChange(of: control.properties) { _ in synchronizeFromControl() }
    .onPreferenceChange(RufletRailDestinationGroupHeightKey.self) {
      destinationGroupHeight = $0
    }
  }

  @ViewBuilder
  private func destinationButton(_ destination: RufletControl, index: Int) -> some View {
    let selected = selectedIndex == index
    Button {
      guard !control.disabled, !destination.disabled else { return }
      selectedIndex = index
      rufletCommitSelection(control: control, index: index, notify: true)
    } label: {
      Group {
        if extended {
          HStack(spacing: 12) {
            destinationIcon(destination, selected: selected)
            destinationLabel(destination, selected: selected)
            Spacer(minLength: 0)
          }
        } else {
          VStack(spacing: 3) {
            destinationIcon(destination, selected: selected)
            if showsLabel(selected: selected) {
              destinationLabel(destination, selected: selected)
            }
          }
        }
      }
      .padding(parsePadding(destination.dynamicValue("padding"))
        ?? EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
      .frame(minWidth: railWidth, alignment: extended ? .leading : .center)
      .background {
        if selected && useIndicator {
          (parseColor(destination.string("indicator_color")) ?? indicatorColor)
            .clipShape(indicatorShape(destination))
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(control.disabled || destination.disabled)
    .opacity(destination.disabled ? 0.45 : 1)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  @ViewBuilder
  private func destinationIcon(_ destination: RufletControl, selected: Bool) -> some View {
    if selected, let selectedIcon = destination.buildIconOrWidget("selected_icon") {
      selectedIcon
    } else if let icon = destination.buildIconOrWidget("icon") {
      icon
    }
  }

  @ViewBuilder
  private func destinationLabel(_ destination: RufletControl, selected: Bool) -> some View {
    if let label = destination.buildTextOrWidget("label", required: true) {
      label
        .modifier(RufletTextStyleModifier(style: selected ? selectedLabelStyle : unselectedLabelStyle))
        .foregroundStyle(selected ? Color.accentColor : Color.primary)
        .lineLimit(1)
    }
  }

  private var destinations: [RufletControl] {
    // Keep the exact Flet slot visible at the concrete renderer boundary.
    rufletNavigationChildren(control, property: "destinations")
  }

  private func synchronizeFromControl() {
    guard let requested = control.integer("selected_index") else {
      selectedIndex = nil
      return
    }
    precondition(
      destinations.indices.contains(requested),
      "NavigationRail.selected_index must be nil or reference a visible destination")
    selectedIndex = requested
  }

  private func showsLabel(selected: Bool) -> Bool {
    guard !extended else { return true }
    return switch labelType {
    case .none: false
    case .selected: selected
    case .all: true
    }
  }

  private func indicatorShape(_ destination: RufletControl) -> RufletCornerShape {
    let details = rufletDictionary(
      destination.dynamicValue("indicator_shape") ?? control.dynamicValue("indicator_shape"))
    let radius = parseBorderRadius(
      details?["border_radius"] ?? details?["radius"],
      RufletBorderRadius(topLeft: 24, topRight: 24, bottomLeft: 24, bottomRight: 24))!
    return RufletCornerShape(radius: radius)
  }

  private var labelType: RufletNavigationRailLabelType {
    parseEnum(RufletNavigationRailLabelType.self, control.string("label_type"), .all)!
  }

  private var extended: Bool { control.boolean("extended", default: false) }
  private var useIndicator: Bool { control.boolean("use_indicator", default: true) }
  private var indicatorColor: Color {
    parseColor(control.string("indicator_color")) ?? Color.accentColor.opacity(0.16)
  }
  private var selectedLabelStyle: RufletTextStyle? {
    parseTextStyle(control.dynamicValue("selected_label_text_style"))
  }
  private var unselectedLabelStyle: RufletTextStyle? {
    parseTextStyle(control.dynamicValue("unselected_label_text_style"))
  }
  private var railWidth: CGFloat {
    CGFloat(extended
      ? control.number("min_extended_width", default: 256) ?? 256
      : control.number("min_width", default: 72) ?? 72)
  }
  private var groupAlignment: Double {
    min(max(control.number("group_alignment", default: -1) ?? -1, -1), 1)
  }
  private var groupFraction: CGFloat { CGFloat((groupAlignment + 1) / 2) }
  private var elevation: CGFloat { CGFloat(max(control.number("elevation") ?? 0, 0)) }
}

private struct RufletRailDestinationGroupHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}
