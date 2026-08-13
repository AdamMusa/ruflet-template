import RufletProtocol
import SwiftUI

struct RufletNavigationDrawerEntry {
  let id: Int
  let control: RufletControl
  let destinationIndex: Int?
}

@MainActor
func rufletNavigationDrawerEntries(_ control: RufletControl) -> [RufletNavigationDrawerEntry] {
  var nextDestination = 0
  return control.children("controls").map { child in
    child.notifyParent = true
    guard child.type == "NavigationDrawerDestination" else {
      return RufletNavigationDrawerEntry(id: child.id, control: child, destinationIndex: nil)
    }
    defer { nextDestination += 1 }
    return RufletNavigationDrawerEntry(
      id: child.id, control: child, destinationIndex: nextDestination)
  }
}

/// Apple-native port of pinned Flet `navigation_drawer.dart`.
@MainActor
public struct NavigationDrawerControl: View {
  @ObservedObject public var control: RufletControl
  @State private var selectedIndex: Int

  public init(control: RufletControl) {
    self.control = control
    _selectedIndex = State(initialValue: control.integer("selected_index", default: 0) ?? 0)
  }

  public var body: some View {
    BaseControl(control: control) {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 2) {
          ForEach(entries, id: \.id) { entry in
            if let index = entry.destinationIndex {
              destination(entry.control, index: index)
            } else {
              ControlWidget(control: entry.control)
            }
          }
        }
        .padding(.vertical, 8)
      }
      .background(parseColor(control.string("bgcolor")) ?? Color.rufletSystemBackground)
      .shadow(
        color: (parseColor(control.string("shadow_color")) ?? .black)
          .opacity(elevation > 0 ? 0.2 : 0),
        radius: elevation,
        x: elevation / 3)
    }
    .onAppear(perform: synchronizeFromControl)
    .onChange(of: control.properties) { _ in synchronizeFromControl() }
  }

  private func destination(_ destination: RufletControl, index: Int) -> some View {
    let selected = index == selectedIndex
    return Button {
      guard !control.disabled, !destination.disabled else { return }
      selectedIndex = index
      rufletCommitSelection(control: control, index: index, notify: true)
    } label: {
      HStack(spacing: 12) {
        if selected, let selectedIcon = destination.buildIconOrWidget("selected_icon") {
          selectedIcon
        } else if let icon = destination.buildIconOrWidget("icon") {
          icon
        }
        Text(destination.string("label", default: "")!)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(tilePadding)
      .frame(minHeight: 44)
      .foregroundStyle(selected ? selectedForeground : Color.primary)
      .background {
        ZStack {
          parseColor(destination.string("bgcolor")) ?? .clear
          if selected {
            indicatorColor.clipShape(indicatorShape)
          }
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(control.disabled || destination.disabled)
    .opacity(destination.disabled ? 0.45 : 1)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var entries: [RufletNavigationDrawerEntry] {
    rufletNavigationDrawerEntries(control)
  }

  private func synchronizeFromControl() {
    let requested = control.integer("selected_index", default: 0) ?? 0
    if selectedIndex != requested { selectedIndex = requested }
  }

  private var tilePadding: EdgeInsets {
    parsePadding(control.dynamicValue("tile_padding"))
      ?? EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
  }

  private var indicatorColor: Color {
    parseColor(control.string("indicator_color")) ?? Color.accentColor.opacity(0.16)
  }

  private var selectedForeground: Color {
    parseColor(control.string("indicator_color")) == nil ? .accentColor : .primary
  }

  private var indicatorShape: RufletCornerShape {
    let value = rufletDictionary(control.dynamicValue("indicator_shape"))
    let radius = parseBorderRadius(
      value?["border_radius"] ?? value?["radius"],
      RufletBorderRadius(topLeft: 24, topRight: 24, bottomLeft: 24, bottomRight: 24))!
    return RufletCornerShape(radius: radius)
  }

  private var elevation: CGFloat {
    CGFloat(max(control.number("elevation") ?? 0, 0))
  }
}
