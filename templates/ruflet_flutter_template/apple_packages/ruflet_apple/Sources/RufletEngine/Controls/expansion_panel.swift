import RufletProtocol
import SwiftUI

/// Apple-native port of pinned `expansion_panel.dart`.
@MainActor
public struct ExpansionPanelListControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      VStack(spacing: spacing) {
        ForEach(Array(panels.enumerated()), id: \.element.id) { index, panel in
          RufletExpansionPanel(
            panel: panel,
            index: index,
            listControl: control,
            dividerColor: dividerColor,
            iconColor: expandedIconColor,
            headerPadding: expandedHeaderPadding,
            elevation: elevation)
        }
      }
    }
  }

  private var panels: [RufletControl] {
    control.children("controls")
  }

  private var spacing: CGFloat {
    CGFloat(control.number("spacing") ?? 16)
  }

  private var elevation: CGFloat {
    CGFloat(max(control.number("elevation") ?? 2, 0))
  }

  private var dividerColor: Color {
    parseColor(control.string("divider_color")) ?? .secondary.opacity(0.24)
  }

  private var expandedIconColor: Color {
    parseColor(control.string("expanded_icon_color")) ?? .accentColor
  }

  private var expandedHeaderPadding: EdgeInsets {
    parseEdgeInsets(control.dynamicValue("expanded_header_padding"))
      ?? EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
  }
}

@MainActor
private struct RufletExpansionPanel: View {
  @ObservedObject var panel: RufletControl
  let index: Int
  @ObservedObject var listControl: RufletControl
  let dividerColor: Color
  let iconColor: Color
  let headerPadding: EdgeInsets
  let elevation: CGFloat
  @State private var expanded: Bool

  init(
    panel: RufletControl,
    index: Int,
    listControl: RufletControl,
    dividerColor: Color,
    iconColor: Color,
    headerPadding: EdgeInsets,
    elevation: CGFloat
  ) {
    self.panel = panel
    self.index = index
    self.listControl = listControl
    self.dividerColor = dividerColor
    self.iconColor = iconColor
    self.headerPadding = headerPadding
    self.elevation = elevation
    _expanded = State(initialValue: panel.boolean("expanded", default: false))
  }

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(expanded ? headerPadding : EdgeInsets())
        .background(headerBackground)

      if expanded {
        Divider().overlay(dividerColor)
        if let content = panel.buildWidget("content") {
          content
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
          ErrorControl("ExpansionPanel.content must be provided and visible")
        }
      }
    }
    .background(parseColor(panel.string("bgcolor")) ?? Color.rufletSystemBackground)
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .shadow(color: .black.opacity(elevation > 0 ? 0.16 : 0), radius: elevation, y: elevation / 2)
    .animation(.easeInOut(duration: 0.2), value: expanded)
    .onAppear {
      panel.notifyParent = true
      synchronize()
    }
    .onChange(of: panel.properties) { _ in synchronize() }
  }

  @ViewBuilder
  private var header: some View {
    if panel.buildWidget("header") == nil {
      ErrorControl("ExpansionPanel.header must be provided and visible")
    } else if panel.boolean("can_tap_header", default: false) {
      Button(action: toggle) { headerRow(showArrowButton: false) }
        .buttonStyle(RufletExpansionHeaderButtonStyle(pressedColor: splashColor))
        .disabled(listControl.disabled || panel.disabled)
    } else {
      headerRow(showArrowButton: true)
    }
  }

  private func headerRow(showArrowButton: Bool) -> some View {
    HStack(spacing: 12) {
      panel.buildWidget("header")
        .frame(maxWidth: .infinity, alignment: .leading)
      if showArrowButton {
        Button(action: toggle) { disclosureIcon }
          .buttonStyle(RufletExpansionHeaderButtonStyle(pressedColor: splashColor))
          .disabled(listControl.disabled || panel.disabled)
      } else {
        disclosureIcon
      }
    }
    .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    .contentShape(Rectangle())
  }

  private var disclosureIcon: some View {
    Image(systemName: "chevron.down")
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(expanded ? iconColor : .secondary)
      .rotationEffect(expanded ? .degrees(180) : .zero)
  }

  private var headerBackground: Color {
    if expanded {
      return parseColor(panel.string("highlight_color")) ?? .clear
    }
    return .clear
  }

  private var splashColor: Color {
    parseColor(panel.string("splash_color")) ?? .accentColor.opacity(0.12)
  }

  private func synchronize() {
    let requested = panel.boolean("expanded", default: false)
    guard requested != expanded else { return }
    withAnimation(.easeInOut(duration: 0.2)) { expanded = requested }
  }

  private func toggle() {
    guard !listControl.disabled, !panel.disabled else { return }
    let next = !expanded
    withAnimation(.easeInOut(duration: 0.2)) { expanded = next }
    rufletCommitExpansion(
      target: panel,
      expanded: next,
      notify: true,
      eventControl: listControl,
      eventData: .int(Int64(index)))
  }
}

private struct RufletExpansionHeaderButtonStyle: ButtonStyle {
  let pressedColor: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label.background(configuration.isPressed ? pressedColor : .clear)
  }
}
