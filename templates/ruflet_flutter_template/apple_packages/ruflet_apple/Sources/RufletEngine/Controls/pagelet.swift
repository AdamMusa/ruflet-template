import RufletProtocol
import SwiftUI

/// Apple-native port of Flet's `pagelet.dart`.
@MainActor
public struct PageletControl: View {
  @ObservedObject public var control: RufletControl
  @State private var drawerPresented = false
  @State private var endDrawerPresented = false
  @State private var invokeToken: UUID?

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      GeometryReader { proxy in
        if proxy.size.height.isInfinite && control.number("height") == nil {
          ErrorControl(
            "Error displaying Pagelet: height is unbounded.",
            description: "Either set a fixed height or nest Pagelet inside expanded control or control with a fixed height.")
        } else if control.child("content") == nil {
          ErrorControl("Pagelet.content must be provided and visible")
        } else {
          scaffold
        }
      }
    }
    .onAppear(perform: mount)
    .onDisappear(perform: unmount)
  }

  private var scaffold: some View {
    ZStack {
      parseColor(control.string("bgcolor")) ?? Color.rufletSystemBackground
      VStack(spacing: 0) {
        if let appBar = control.child("appbar") {
          pageletAppBar(appBar)
        }
        control.buildWidget("content")!
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        if let bottom = control.child("navigation_bar") ?? control.child("bottom_appbar") {
          ControlWidget(control: bottom)
        }
      }
      if let sheet = control.child("bottom_sheet") {
        ControlWidget(control: sheet)
      }
      if let floating = control.child("floating_action_button") {
        ControlWidget(control: floating)
          .padding(16)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: floatingAlignment)
      }
      drawerLayers
    }
    .clipped()
  }

  @ViewBuilder
  private func pageletAppBar(_ appBar: RufletControl) -> some View {
    if pageletDesign == .cupertino || appBar.type == "CupertinoAppBar" {
      RufletAppleAppBar(control: appBar, kind: .cupertino)
    } else {
      AppBarControl(control: appBar)
    }
  }

  private var pageletDesign: RufletPageDesign {
    rufletPageDesign(
      adaptive: control.boolean("adaptive", default: false),
      platform: nil,
      defaultPlatform: rufletDefaultTargetPlatform)
  }

  @ViewBuilder
  private var drawerLayers: some View {
    if let drawer = control.child("drawer"), drawerPresented {
      RufletPageletDrawer(edge: .leading) {
        ControlWidget(control: drawer)
      } onDismiss: {
        drawerPresented = false
        control.backend.triggerControlEvent(controlID: drawer.id, name: "dismiss", data: .null)
      }
    }
    if let drawer = control.child("end_drawer"), endDrawerPresented {
      RufletPageletDrawer(edge: .trailing) {
        ControlWidget(control: drawer)
      } onDismiss: {
        endDrawerPresented = false
        control.backend.triggerControlEvent(controlID: drawer.id, name: "dismiss", data: .null)
      }
    }
  }

  private func mount() {
    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { name, _ in
      switch name {
      case "show_drawer": drawerPresented = control.child("drawer") != nil
      case "close_drawer": drawerPresented = false
      case "show_end_drawer": endDrawerPresented = control.child("end_drawer") != nil
      case "close_end_drawer": endDrawerPresented = false
      default: throw RufletPageletError.unknownMethod(name)
      }
      return .null
    }
  }

  private func unmount() {
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
  }

  private var floatingAlignment: Alignment {
    switch control.string("floating_action_button_location")?.lowercased() {
    case let value? where value.contains("center"): .bottom
    case let value? where value.contains("start"): .bottomLeading
    default: .bottomTrailing
    }
  }
}

private enum RufletPageletError: LocalizedError {
  case unknownMethod(String)
  var errorDescription: String? {
    switch self { case .unknownMethod(let name): "Unknown Pagelet method: \(name)" }
  }
}

private struct RufletPageletDrawer<Content: View>: View {
  let edge: Edge
  @ViewBuilder let content: () -> Content
  let onDismiss: () -> Void

  var body: some View {
    ZStack(alignment: edge == .leading ? .leading : .trailing) {
      Color.black.opacity(0.28)
        .ignoresSafeArea()
        .onTapGesture(perform: onDismiss)
      content()
        .frame(maxWidth: 360, maxHeight: .infinity)
        .background(Color.rufletSystemBackground)
        .transition(.move(edge: edge))
    }
    .accessibilityAddTraits(.isModal)
  }
}
