import RufletProtocol
import SwiftUI

enum RufletContextMenuButton: String, Hashable, Sendable {
  case primary, secondary, tertiary
}

enum RufletContextMenuTrigger: String, Sendable {
  case disabled, down
  case longPress = "longPress"

  init(_ value: String?, default defaultValue: RufletContextMenuTrigger) {
    switch value?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "down": self = .down
    case "longpress": self = .longPress
    case "disabled": self = .disabled
    default: self = defaultValue
    }
  }
}

struct RufletContextMenuInvocation: Sendable {
  let button: RufletContextMenuButton?
  let globalPosition: CGPoint
  let localPosition: CGPoint
}

/// Apple-native port of pinned `context_menu.dart`.
@MainActor
public struct ContextMenuControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var model = RufletContextMenuModel()

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      if let content = control.buildWidget("content") {
        content
          .background(
            GeometryReader { contentProxy in
              Color.clear
                .onAppear { updateGeometry(contentProxy) }
                .onChange(of: contentProxy.size) { _ in updateGeometry(contentProxy) }
            }
          )
          .overlay {
            RufletContextMenuPointerBridge(
              primaryTrigger: primaryTrigger,
              secondaryTrigger: secondaryTrigger,
              tertiaryTrigger: tertiaryTrigger,
              onTrigger: pointerTriggered)
          }
          .overlay(alignment: .topLeading) {
            if model.presented {
              ZStack(alignment: .topLeading) {
                Color.clear
                  .contentShape(Rectangle())
                  .onTapGesture { model.dismiss(control: control) }
                menuPanel
                  .offset(x: model.localPosition.x, y: model.localPosition.y)
                  .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                  .zIndex(1)
              }
            }
          }
      } else {
        ErrorControl("ContextMenu.content must be visible")
      }
    }
    .onAppear { model.attach(to: control) }
    .onDisappear { model.detach(from: control) }
  }

  private var menuPanel: some View {
    VStack(spacing: 0) {
      ForEach(entries, id: \.id) { entry in
        switch entry {
        case .divider:
          Divider().frame(height: 16)
        case .item(let item, let checked, let height, let padding):
          Button {
            if let checked {
              item.triggerEvent("click", data: .bool(!checked))
            } else {
              item.triggerEvent("click")
            }
            model.select(item: item, control: control)
          } label: {
            RufletContextMenuItemLabel(item: item, checked: checked)
              .padding(padding ?? EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
              .frame(maxWidth: .infinity, minHeight: CGFloat(height), alignment: .leading)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .disabled(item.disabled || control.disabled)
          .modifier(RufletMouseCursorModifier(cursor: item.string("mouse_cursor")))
        }
      }
    }
    .frame(width: 240)
    .fixedSize(horizontal: false, vertical: true)
    .background(Color.rufletSystemBackground)
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.24), radius: 12, y: 5)
  }

  private var primaryTrigger: RufletContextMenuTrigger {
    RufletContextMenuTrigger(control.string("primary_trigger"), default: .disabled)
  }

  private var secondaryTrigger: RufletContextMenuTrigger {
    RufletContextMenuTrigger(control.string("secondary_trigger"), default: .down)
  }

  private var tertiaryTrigger: RufletContextMenuTrigger {
    RufletContextMenuTrigger(control.string("tertiary_trigger"), default: .down)
  }

  private var entries: [RufletPopupMenuEntry] {
    buildPopupMenuEntries(model.items(for: control))
  }

  private func updateGeometry(_ proxy: GeometryProxy) {
    model.updateGeometry(size: proxy.size, globalOrigin: proxy.frame(in: .global).origin)
  }

  private func pointerTriggered(_ invocation: RufletContextMenuInvocation) {
    model.open(invocation, control: control)
  }
}

@MainActor
private final class RufletContextMenuModel: ObservableObject {
  @Published private(set) var presented = false
  @Published private(set) var invocation: RufletContextMenuInvocation?

  private var invokeToken: UUID?
  private var contentSize = CGSize.zero
  private var globalOrigin = CGPoint.zero

  var localPosition: CGPoint {
    guard let invocation else { return .zero }
    return CGPoint(
      x: min(max(invocation.localPosition.x, 0), max(contentSize.width - 240, 0)),
      y: min(max(invocation.localPosition.y, 0), contentSize.height))
  }

  func updateGeometry(size: CGSize, globalOrigin: CGPoint) {
    contentSize = size
    self.globalOrigin = globalOrigin
  }

  func attach(to control: RufletControl) {
    guard invokeToken == nil else { return }
    self.control = control
    invokeToken = control.addInvokeMethodListener { [weak self, weak control] name, arguments in
      guard name == "open" else { throw RufletContextMenuError.unsupportedMethod(name) }
      guard let self, let control else { return .null }
      let values = arguments.map ?? [:]
      let suppliedGlobal = Self.point(values["global_position"])
      let suppliedLocal = Self.point(values["local_position"])
      let local =
        suppliedLocal ?? suppliedGlobal.map {
          CGPoint(x: $0.x - self.globalOrigin.x, y: $0.y - self.globalOrigin.y)
        } ?? CGPoint(x: self.contentSize.width / 2, y: self.contentSize.height / 2)
      let global =
        suppliedGlobal
        ?? CGPoint(
          x: self.globalOrigin.x + local.x, y: self.globalOrigin.y + local.y)
      self.open(
        RufletContextMenuInvocation(button: nil, globalPosition: global, localPosition: local),
        control: control)
      return .null
    }
  }

  func detach(from control: RufletControl) {
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
    presented = false
    self.control = nil
  }

  func open(_ invocation: RufletContextMenuInvocation, control: RufletControl) {
    if presented { dismiss(control: control) }
    self.invocation = invocation
    let entryCount = buildPopupMenuEntries(items(for: control)).count
    guard entryCount > 0 else {
      control.triggerEvent("dismiss", data: eventPayload(itemCount: entryCount))
      return
    }
    withAnimation(.easeOut(duration: 0.12)) { presented = true }
  }

  func select(item: RufletControl, control: RufletControl) {
    guard presented else { return }
    let popupItems = items(for: control)
    withAnimation(.easeOut(duration: 0.1)) { presented = false }
    control.triggerEvent(
      "select",
      data: eventPayload(
        itemID: item.id,
        itemIndex: popupItems.firstIndex { $0.id == item.id },
        itemCount: popupItems.count))
  }

  func dismiss(control: RufletControl) {
    guard presented else { return }
    let count = items(for: control).count
    withAnimation(.easeOut(duration: 0.1)) { presented = false }
    control.triggerEvent("dismiss", data: eventPayload(itemCount: count))
  }

  func items(for control: RufletControl) -> [RufletControl] {
    switch invocation?.button {
    case .primary: return control.children("primary_items")
    case .secondary: return control.children("secondary_items")
    case .tertiary: return control.children("tertiary_items")
    case nil: return control.children("items")
    }
  }

  private func eventPayload(
    itemID: Int? = nil, itemIndex: Int? = nil, itemCount: Int
  ) -> RufletValue {
    guard let invocation else { return .null }
    return [
      "b": invocation.button.map { .string($0.rawValue) } ?? .null,
      "tr": invocation.button.map { .string(trigger(for: $0).rawValue) } ?? .null,
      "id": itemID.map { .int(Int64($0)) } ?? .null,
      "idx": itemIndex.map { .int(Int64($0)) } ?? .null,
      "ic": .int(Int64(itemCount)),
      "g": [
        "x": .double(Double(invocation.globalPosition.x)),
        "y": .double(Double(invocation.globalPosition.y)),
      ],
      "l": [
        "x": .double(Double(invocation.localPosition.x)),
        "y": .double(Double(invocation.localPosition.y)),
      ],
    ]
  }

  private func trigger(for button: RufletContextMenuButton) -> RufletContextMenuTrigger {
    guard let control else { return .disabled }
    switch button {
    case .primary:
      return RufletContextMenuTrigger(control.string("primary_trigger"), default: .disabled)
    case .secondary:
      return RufletContextMenuTrigger(control.string("secondary_trigger"), default: .down)
    case .tertiary:
      return RufletContextMenuTrigger(control.string("tertiary_trigger"), default: .down)
    }
  }

  private weak var control: RufletControl?

  private static func point(_ value: RufletValue?) -> CGPoint? {
    guard let value else { return nil }
    if let values = value.array, values.count > 1,
      let x = values[0].number, let y = values[1].number
    {
      return CGPoint(x: x, y: y)
    }
    guard let values = value.map,
      let x = values["x"]?.number, let y = values["y"]?.number
    else { return nil }
    return CGPoint(x: x, y: y)
  }
}

private enum RufletContextMenuError: Error {
  case unsupportedMethod(String)
}

@MainActor
private struct RufletContextMenuItemLabel: View {
  @ObservedObject var item: RufletControl
  let checked: Bool?
  @Environment(\.isEnabled) private var enabled
  @State private var hovered = false

  var body: some View {
    HStack(spacing: 8) {
      if let checked {
        if checked {
          Image(systemName: "checkmark").frame(width: 16)
        } else {
          Color.clear.frame(width: 16, height: 1)
        }
      }
      if let icon = item.buildIconOrWidget("icon") { icon }
      if let content = item.buildTextOrWidget("content") {
        content
          .modifier(RufletTextStyleModifier(style: labelStyle))
          .lineLimit(1)
      }
    }
    .onHover { hovered = $0 }
  }

  private var labelStyle: RufletTextStyle? {
    var states: Set<RufletWidgetState> = []
    if !enabled { states.insert(.disabled) }
    if hovered { states.insert(.hovered) }
    return RufletWidgetStateProperty(
      item.dynamicValue("label_text_style"), converter: { parseTextStyle($0) }
    )
    .resolve(states)
  }
}
