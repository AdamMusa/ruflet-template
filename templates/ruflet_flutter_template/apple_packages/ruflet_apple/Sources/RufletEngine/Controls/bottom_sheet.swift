import RufletProtocol
import SwiftUI

/// Apple-native port of pinned `bottom_sheet.dart`.
@MainActor
public struct BottomSheetControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    RufletAppleSheetPresenter(control: control, kind: .standard)
  }
}

@MainActor
struct RufletAppleSheetPresenter: View {
  enum Kind { case standard, cupertino }

  @ObservedObject var control: RufletControl
  let kind: Kind
  @State private var presented = false
  @State private var closedByControl = false

  var body: some View {
    #if os(iOS)
    Group {
      if fullscreen && kind == .standard {
        anchor.fullScreenCover(isPresented: $presented, onDismiss: dismissed) { sheetContent }
      } else {
        anchor.sheet(isPresented: $presented, onDismiss: dismissed) { sheetContent }
      }
    }
    .onAppear(perform: synchronizePresentation)
    .onChange(of: control.properties) { _ in synchronizePresentation() }
    #elseif os(macOS)
    anchor
      .sheet(isPresented: $presented, onDismiss: dismissed) { sheetContent }
      .onAppear(perform: synchronizePresentation)
      .onChange(of: control.properties) { _ in synchronizePresentation() }
    #endif
  }

  private var anchor: some View { Color.clear.frame(width: 0, height: 0) }

  @ViewBuilder
  private var sheetContent: some View {
    let body = Group {
      if let content = control.buildWidget("content") {
        if scrollable { ScrollView { content } } else { content }
      }
    }
    .frame(
      minWidth: constraint("min_width"),
      maxWidth: constraint("max_width"),
      minHeight: constraint("min_height"),
      maxHeight: constraint("max_height"))
    .frame(height: cupertinoPickerHeight)
    .frame(maxWidth: fullscreen ? .infinity : nil, maxHeight: fullscreen ? .infinity : nil)
    .padding(kind == .cupertino ? parsePadding(control.dynamicValue("padding")) ?? EdgeInsets() : EdgeInsets())
    .background(parseColor(control.string("bgcolor")) ?? Color.rufletSystemBackground)
    .clipShape(sheetShape)
    .modifier(RufletSheetKeyboardInsets(
      maintains: kind == .cupertino || control.boolean("maintain_bottom_view_insets_padding", default: true)))
    .modifier(RufletSheetSafeArea(
      enabled: kind == .cupertino || control.boolean("use_safe_area", default: true)))
    .interactiveDismissDisabled(!dismissible)

    if kind == .standard, control.boolean("show_drag_handle", default: false) {
      VStack(spacing: 0) {
        Capsule().fill(Color.secondary.opacity(0.55)).frame(width: 36, height: 5).padding(.vertical, 8)
        body
      }
    } else {
      body
    }
  }

  private func synchronizePresentation() {
    let open = control.boolean("open", default: false)
    let lastOpen = control.boolean("_open", default: false)
    if open, !lastOpen, !presented, control.child("content") != nil {
      control.updateProperties(["_open": .bool(true)], server: false)
      closedByControl = false
      presented = true
    } else if !open, lastOpen, presented {
      closedByControl = true
      presented = false
    }
  }

  private func dismissed() {
    control.updateProperties(["_open": .bool(false)], server: false)
    control.updateProperties(["open": .bool(false)])
    control.triggerEvent("dismiss")
    closedByControl = false
  }

  private var fullscreen: Bool { control.boolean("fullscreen", default: false) }
  private var scrollable: Bool {
    fullscreen || control.boolean("scrollable", default: false)
  }
  private var dismissible: Bool {
    kind == .cupertino
      ? !control.boolean("modal", default: false)
      : control.boolean("dismissible", default: true)
  }
  private var sheetShape: RufletCornerShape {
    let details = rufletDictionary(control.dynamicValue("shape"))
    let radius = parseBorderRadius(details?["radius"],
      RufletBorderRadius(topLeft: 14, topRight: 14, bottomLeft: 0, bottomRight: 0))!
    return RufletCornerShape(radius: radius)
  }
  private func constraint(_ name: String) -> CGFloat? {
    guard kind == .standard,
          let value = parseDouble(rufletDictionary(control.dynamicValue("size_constraints"))?[name]),
          value.isFinite
    else { return nil }
    return CGFloat(value)
  }
  private var cupertinoPickerHeight: CGFloat? {
    guard kind == .cupertino,
          let content = control.child("content"),
          ["CupertinoPicker", "CupertinoTimerPicker", "CupertinoDatePicker"].contains(content.type)
    else { return nil }
    return CGFloat(control.number("height", default: 220) ?? 220)
  }
}

private struct RufletSheetKeyboardInsets: ViewModifier {
  let maintains: Bool
  @ViewBuilder func body(content: Content) -> some View {
    if maintains { content } else { content.ignoresSafeArea(.keyboard, edges: .bottom) }
  }
}

private struct RufletSheetSafeArea: ViewModifier {
  let enabled: Bool
  @ViewBuilder func body(content: Content) -> some View {
    if enabled { content } else { content.ignoresSafeArea() }
  }
}
