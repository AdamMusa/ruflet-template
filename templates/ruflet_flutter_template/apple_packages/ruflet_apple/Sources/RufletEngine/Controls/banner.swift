import RufletProtocol
import SwiftUI

/// Apple-native port of Flet's `banner.dart`.
@MainActor
public struct BannerControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    Group {
      if control.boolean("open", default: false) {
        if control.child("content") == nil && control.string("content") == nil {
          ErrorControl("Banner.content must be provided and visible")
        } else if control.children("actions").isEmpty {
          ErrorControl("Banner.actions must be provided and at least one action should be visible")
        } else {
          banner
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .onAppear(perform: synchronizeLifecycle)
    .onChange(of: control.properties) { _ in synchronizeLifecycle() }
  }

  private var banner: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        if let leading = control.buildIconOrWidget("leading") {
          leading.padding(parsePadding(control.dynamicValue("leading_padding")) ?? EdgeInsets())
        }
        control.buildTextOrWidget("content")!
          .modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("content_text_style"))))
          .padding(parsePadding(control.dynamicValue("content_padding")) ?? EdgeInsets())
          .frame(maxWidth: .infinity, alignment: .leading)
        if !control.boolean("force_actions_below", default: false) {
          actions
        }
      }
      if control.boolean("force_actions_below", default: false) {
        actions.frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .padding(12)
    .frame(minHeight: CGFloat(control.number("min_action_bar_height") ?? 52))
    .background(parseColor(control.string("bgcolor")) ?? Color.rufletSystemBackground)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(parseColor(control.string("divider_color")) ?? .secondary.opacity(0.25))
        .frame(height: 0.5)
    }
    .shadow(
      color: parseColor(control.string("shadow_color")) ?? .black.opacity(0.16),
      radius: CGFloat(max(control.number("elevation") ?? 0, 0)))
    .padding(parseMargin(control.dynamicValue("margin")) ?? EdgeInsets())
    .transition(.move(edge: .top).combined(with: .opacity))
  }

  private var actions: some View {
    HStack(spacing: 8) {
      ForEach(control.children("actions")) { action in
        ControlWidget(control: action)
      }
    }
  }

  private func synchronizeLifecycle() {
    let open = control.boolean("open", default: false)
    let lastOpen = control.boolean("_open", default: false)
    if open && !lastOpen {
      let generation = (control.integer("_show_generation", default: 0) ?? 0) + 1
      control.updateProperties(
        [
          "_open": .bool(true),
          "_dismissed": .bool(false),
          "_show_generation": .int(Int64(generation)),
        ],
        client: true,
        server: false,
        notify: true)
      control.triggerEvent("visible")
    } else if !open && lastOpen {
      control.updateProperties(
        ["_open": .bool(false), "_dismissed": .bool(true)],
        client: true,
        server: false,
        notify: true)
      control.triggerEvent("dismiss")
    }
  }
}
