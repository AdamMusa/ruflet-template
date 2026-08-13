import SwiftUI

/// Apple-native port of pinned `cupertino_list_tile.dart`.
@MainActor
public struct CupertinoListTileControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var clickNotifier = RufletListTileClickNotifier()
  @GestureState private var pressed = false

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      if let title = control.buildTextOrWidget("title") {
        tile(title: title)
          .environment(
            \.rufletListTileClickNotifier,
            control.boolean("toggle_inputs", default: false) ? clickNotifier : nil)
      } else {
        ErrorControl("CupertinoListTile.title must be provided and visible")
      }
    }
  }

  private func tile(title: AnyView) -> some View {
    HStack(alignment: .center, spacing: leadingToTitle) {
      if let leading = control.buildIconOrWidget("leading") {
        leading.frame(width: leadingSize, height: leadingSize)
      }

      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          title
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
          if let additionalInfo = control.buildTextOrWidget("additional_info") {
            additionalInfo
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        if let subtitle = control.buildTextOrWidget("subtitle") {
          subtitle
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      if let trailing = control.buildIconOrWidget("trailing") { trailing }
    }
    .padding(contentPadding)
    .frame(minHeight: notched ? 50 : 44)
    .background(backgroundColor)
    .contentShape(Rectangle())
    .opacity(control.disabled ? 0.5 : 1)
    .onTapGesture(perform: tap)
    .simultaneousGesture(
      DragGesture(minimumDistance: 0).updating($pressed) { _, state, _ in state = true })
  }

  private var notched: Bool {
    control.boolean("notched", default: false)
  }

  private var leadingSize: CGFloat {
    CGFloat(control.number("leading_size") ?? (notched ? 30 : 28))
  }

  private var leadingToTitle: CGFloat {
    CGFloat(control.number("leading_to_title") ?? (notched ? 12 : 16))
  }

  private var contentPadding: EdgeInsets {
    parsePadding(control.dynamicValue("content_padding"))
      ?? EdgeInsets(
        top: notched ? 8 : 10,
        leading: notched ? 20 : 16,
        bottom: notched ? 8 : 10,
        trailing: 16)
  }

  private var backgroundColor: Color {
    if pressed {
      return parseColor(control.string("bgcolor_activated")) ?? Color.primary.opacity(0.08)
    }
    return parseColor(control.string("bgcolor")) ?? .clear
  }

  private var canTap: Bool {
    !control.disabled
      && (control.boolean("on_click", default: false)
        || control.boolean("toggle_inputs", default: false)
        || parseURL(control.dynamicValue("url")) != nil)
  }

  private func tap() {
    guard canTap else { return }
    if control.boolean("toggle_inputs", default: false) { clickNotifier.onClick() }
    if let url = parseURL(control.dynamicValue("url")) { Task { await openURL(url) } }
    if control.boolean("on_click", default: false) { control.triggerEvent("click") }
  }
}
