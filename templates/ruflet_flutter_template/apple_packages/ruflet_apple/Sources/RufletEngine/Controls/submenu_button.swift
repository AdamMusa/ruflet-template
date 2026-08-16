import SwiftUI

/// Apple-native port of pinned Flet `submenu_button.dart`.
@MainActor
public struct SubmenuButtonControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.rufletDismissMenu) private var dismissParentMenu
  @FocusState private var focused: Bool
  @State private var hovered = false
  @State private var presented = false
  @State private var lastFocusValue: String?

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      Button(action: open) {
        HStack(spacing: 8) {
          if let leading = control.buildWidget("leading") { leading }
          if let content = control.buildTextOrWidget("content") { content }
          Spacer(minLength: 8)
          if let trailing = control.buildWidget("trailing") {
            trailing
          } else {
            Image(systemName: "chevron.right")
              .imageScale(.small)
              .foregroundStyle(.secondary)
          }
        }
      }
      .buttonStyle(
        RufletAppleMenuButtonStyle(
          appearance: RufletMenuButtonAppearance(control: control),
          focused: focused,
          hovered: hovered,
          disabled: control.disabled)
      )
      .disabled(control.disabled)
      .focused($focused)
      .onHover(perform: hoverChanged)
      .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
      .onAppear(perform: synchronizeFocus)
      .onChange(of: control.properties) { _ in synchronizeFocus() }
      .modifier(RufletMenuClipModifier(behavior: clipBehavior))
      .popover(
        isPresented: presentationBinding,
        attachmentAnchor: .rect(.bounds),
        arrowEdge: .leading
      ) {
        menuPanel
      }
    }
  }

  private var menuPanel: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(children) { child in
        ControlWidget(control: child)
      }
    }
    .frame(minWidth: 200, alignment: .leading)
    .modifier(
      RufletAppleMenuSurfaceModifier(
        style: control.menuStyle("menu_style"),
        rawStyle: control.dynamicValue("menu_style"),
        defaultPadding: EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
    )
    .offset(alignmentOffset)
    .environment(\.rufletDismissMenu, RufletMenuDismissAction(perform: dismissHierarchy))
  }

  private func open() {
    guard !control.disabled else { return }
    setPresented(true)
  }

  private func dismissHierarchy() {
    setPresented(false)
    dismissParentMenu()
  }

  private func setPresented(_ value: Bool) {
    guard presented != value else { return }
    guard !value || !control.disabled else { return }
    presented = value
    if value {
      if control.boolean("on_open", default: false) { control.triggerEvent("open") }
    } else if control.boolean("on_close", default: false) {
      control.triggerEvent("close")
    }
  }

  private func hoverChanged(_ value: Bool) {
    hovered = value
    guard !control.disabled, control.boolean("on_hover", default: false) else { return }
    control.triggerEvent("hover", data: .bool(value))
  }

  private func synchronizeFocus() {
    guard let value = control.string("focus"), value != lastFocusValue else { return }
    lastFocusValue = value
    focused = true
  }

  private var presentationBinding: Binding<Bool> {
    Binding(get: { presented }, set: { setPresented($0) })
  }
  private var children: [RufletControl] {
    rufletMenuChildren(control, property: "controls")
  }
  private var alignmentOffset: CGSize {
    parseOffset(control.dynamicValue("alignment_offset")) ?? .zero
  }
  private var clipBehavior: String {
    control.string("clip_behavior", default: "hardEdge")!.lowercased()
  }
}
