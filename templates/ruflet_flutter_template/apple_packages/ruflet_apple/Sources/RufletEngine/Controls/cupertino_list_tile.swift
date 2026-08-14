import SwiftUI

/// Apple-native port of pinned `cupertino_list_tile.dart`.
@MainActor
public struct CupertinoListTileControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var clickNotifier = RufletListTileClickNotifier()

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      if let title = control.buildTextOrWidget("title") {
        interactiveTile(title: title)
          .environment(
            \.rufletListTileClickNotifier,
            control.boolean("toggle_inputs", default: false) ? clickNotifier : nil)
      } else {
        ErrorControl("CupertinoListTile.title must be provided and visible")
      }
    }
  }

  @ViewBuilder
  private func interactiveTile(title: AnyView) -> some View {
    if activation.isEnabled {
      Button(action: activation.callAsFunction) { tile(title: title) }
        .buttonStyle(RufletCupertinoListTileButtonStyle(
          pressedColor: activatedBackgroundColor))
    } else {
      tile(title: title)
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
      ?? RufletLayoutDefaults.cupertinoListTile(
        notched: notched,
        hasLeading: control.child("leading") != nil)
  }

  private var backgroundColor: Color {
    return parseColor(control.string("bgcolor")) ?? .clear
  }

  private var activatedBackgroundColor: Color {
    parseColor(control.string("bgcolor_activated")) ?? Color.primary.opacity(0.08)
  }

  private var activation: RufletListTileActivation {
    RufletListTileActivation(control: control, clickNotifier: clickNotifier)
  }
}

private struct RufletCupertinoListTileButtonStyle: ButtonStyle {
  let pressedColor: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .overlay {
        if configuration.isPressed {
          Rectangle().fill(pressedColor).allowsHitTesting(false)
        }
      }
  }
}
