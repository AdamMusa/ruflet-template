import SwiftUI

@MainActor
func rufletSelectPopupMenuEntry(
  _ entry: RufletPopupMenuEntry,
  from control: RufletControl
) {
  guard !control.disabled else { return }
  switch entry {
  case .divider:
    return
  case .item(let item, let checked, _, _):
    guard !item.disabled else { return }
    if let checked {
      item.triggerEvent("click", data: .bool(!checked))
    } else {
      item.triggerEvent("click")
    }
    control.triggerEvent("select", data: .string(String(item.id)))
  }
}

/// Apple-native port of pinned Flet `popup_menu_button.dart`.
@MainActor
public struct PopupMenuButtonControl: View {
  @ObservedObject public var control: RufletControl
  @State private var presented = false
  @State private var selectionCommitted = false

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      Button(action: open) {
        triggerLabel
      }
      .buttonStyle(
        RufletAppleMenuButtonStyle(
          appearance: RufletMenuButtonAppearance(control: control),
          focused: false,
          hovered: false,
          disabled: control.disabled)
      )
      .disabled(control.disabled)
      .accessibilityLabel(control.string("tooltip") ?? "Show menu")
      .modifier(RufletMenuClipModifier(behavior: clipBehavior))
      .popover(
        isPresented: presentationBinding,
        attachmentAnchor: .rect(.bounds),
        arrowEdge: arrowEdge
      ) {
        popupPanel
      }
    }
    .onDisappear {
      if presented { setPresented(false) }
    }
    .onChange(of: control.disabled) { disabled in
      if disabled, presented { setPresented(false) }
    }
  }

  @ViewBuilder
  private var triggerLabel: some View {
    if let content = control.buildTextOrWidget("content") {
      content
    } else if let icon = control.buildIconOrWidget(
      "icon", color: parseColor(control.string("icon_color")))
    {
      icon.frame(width: iconSize, height: iconSize)
    } else {
      Image(systemName: "ellipsis.circle")
        .resizable()
        .scaledToFit()
        .foregroundStyle(parseColor(control.string("icon_color")) ?? .accentColor)
        .frame(width: iconSize, height: iconSize)
    }
  }

  private var popupPanel: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(entries, id: \.id) { entry in
        switch entry {
        case .divider:
          Divider()
        case .item(let item, let checked, let height, let padding):
          popupItem(
            entry: entry,
            item: item,
            checked: checked,
            height: height,
            padding: padding)
        }
      }
    }
    .padding(menuPadding)
    .modifier(RufletPopupMenuSizeModifier(constraints: sizeConstraints))
    .background(backgroundColor)
    .clipShape(RufletCornerShape(radius: popupRadius))
    .overlay {
      if let side = popupSide {
        RufletCornerShape(radius: popupRadius).stroke(side.color, lineWidth: side.width)
      }
    }
    .shadow(color: shadowColor, radius: elevation, y: elevation / 2)
    .modifier(RufletMenuClipModifier(behavior: clipBehavior))
  }

  private func popupItem(
    entry: RufletPopupMenuEntry,
    item: RufletControl,
    checked: Bool?,
    height: Double,
    padding: EdgeInsets?
  ) -> some View {
    Button {
      selectionCommitted = true
      rufletSelectPopupMenuEntry(entry, from: control)
      setPresented(false)
    } label: {
      HStack(spacing: 8) {
        if let checked {
          Group {
            if checked {
              Image(systemName: "checkmark")
            } else {
              Color.clear
            }
          }
          .frame(width: 16, height: 16)
        }
        if let icon = item.buildIconOrWidget("icon") { icon }
        if let content = item.buildTextOrWidget("content") {
          content
            .modifier(RufletTextStyleModifier(style: popupItemTextStyle(item)))
        }
      }
      .frame(maxWidth: .infinity, minHeight: CGFloat(height), alignment: .leading)
      .padding(padding ?? EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(control.disabled || item.disabled)
    .opacity(item.disabled ? 0.45 : 1)
  }

  private func open() {
    guard !control.disabled else { return }
    setPresented(true)
  }

  private func setPresented(_ value: Bool) {
    guard value != presented else { return }
    if value {
      guard !control.disabled else { return }
      selectionCommitted = false
      withAnimation(presentationAnimation(opening: true)) { presented = true }
      control.triggerEvent("open")
    } else {
      withAnimation(presentationAnimation(opening: false)) { presented = false }
      if selectionCommitted {
        selectionCommitted = false
      } else {
        control.triggerEvent("cancel")
      }
    }
  }

  private var presentationBinding: Binding<Bool> {
    Binding(get: { presented }, set: { setPresented($0) })
  }
  private var entries: [RufletPopupMenuEntry] {
    buildPopupMenuEntries(control.children("items"))
  }
  private var iconSize: CGFloat {
    CGFloat(max(control.number("icon_size") ?? 22, 0))
  }
  private var menuPadding: EdgeInsets {
    parsePadding(control.dynamicValue("menu_padding"))
      ?? EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
  }
  private var backgroundColor: Color {
    parseColor(control.string("bgcolor")) ?? Color.rufletSystemBackground
  }
  private var shadowColor: Color {
    parseColor(control.string("shadow_color")) ?? .black.opacity(0.22)
  }
  private var elevation: CGFloat { CGFloat(max(control.number("elevation") ?? 8, 0)) }
  private var clipBehavior: String {
    control.string("clip_behavior", default: "none")!.lowercased()
  }
  private var arrowEdge: Edge {
    control.string("menu_position")?.lowercased() == "over" ? .bottom : .top
  }
  private var sizeConstraints: RufletPopupMenuSizeConstraints {
    RufletPopupMenuSizeConstraints(control.dynamicValue("size_constraints"))
  }
  private var popupRadius: RufletBorderRadius {
    let details = rufletDictionary(control.dynamicValue("shape"))
    return parseBorderRadius(
      details?["border_radius"] ?? details?["radius"] ?? control.dynamicValue("shape"),
      RufletBorderRadius(topLeft: 10, topRight: 10, bottomLeft: 10, bottomRight: 10))!
  }
  private var popupSide: RufletBorderSide? {
    let details = rufletDictionary(control.dynamicValue("shape"))
    return parseBorderSide(details?["side"])
  }

  private func popupItemTextStyle(_ item: RufletControl) -> RufletTextStyle? {
    let states: Set<RufletWidgetState> = item.disabled ? [.disabled] : []
    return RufletWidgetStateProperty<RufletTextStyle>(
      item.dynamicValue("label_text_style"), converter: { parseTextStyle($0) }
    )
    .resolve(states)
  }

  private func presentationAnimation(opening: Bool) -> Animation {
    guard let details = rufletDictionary(control.dynamicValue("popup_animation_style")) else {
      return .easeOut(duration: opening ? 0.18 : 0.12)
    }
    let durationName = opening ? "duration" : "reverse_duration"
    let curveName = opening ? "curve" : "reverse_curve"
    let duration = parseDuration(details[durationName], opening ? 0.18 : 0.12)!
    let curve = parseCurve(details[curveName] as? String, .ease)!
    return curve.animation(duration: duration)
  }
}

struct RufletPopupMenuSizeConstraints {
  let minWidth: CGFloat?
  let maxWidth: CGFloat?
  let minHeight: CGFloat?
  let maxHeight: CGFloat?

  init(_ value: Any?) {
    let details = rufletDictionary(value)
    minWidth = details?["min_width"].flatMap { parseDouble($0) }.map { CGFloat($0) }
    maxWidth = details?["max_width"].flatMap { parseDouble($0) }.map { CGFloat($0) }
    minHeight = details?["min_height"].flatMap { parseDouble($0) }.map { CGFloat($0) }
    maxHeight = details?["max_height"].flatMap { parseDouble($0) }.map { CGFloat($0) }
  }
}

private struct RufletPopupMenuSizeModifier: ViewModifier {
  let constraints: RufletPopupMenuSizeConstraints

  func body(content: Content) -> some View {
    content.frame(
      minWidth: constraints.minWidth,
      maxWidth: constraints.maxWidth,
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
      alignment: .leading)
  }
}
