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
  @State private var dragOffset: CGFloat = 0

  var body: some View {
    ZStack(alignment: .bottom) {
      RufletPresentationLifecycleAnchor()
      if let validationError {
        ErrorControl(validationError)
      } else if presented {
        barrierColor
          .ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture {
            if dismissible { dismissFromUser() }
          }
          .transition(.opacity)
        sheetContent
          .offset(y: dragOffset)
          .gesture(dragGesture)
          .transition(.move(edge: .bottom))
          .zIndex(1)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear(perform: synchronizePresentation)
    .onChange(of: control.properties) { _ in synchronizePresentation() }
  }

  @ViewBuilder
  private var sheetContent: some View {
    let body = Group {
      if let content = control.buildWidget("content") {
        if scrollable { ScrollView { content } } else { content }
      } else {
        ErrorControl(modalKind.missingContentMessage)
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
    .background(parseColor(control.string("bgcolor")) ?? Color.rufletSystemBackground, in: sheetShape)
    .modifier(RufletSheetClip(behavior: control.string("clip_behavior", default: "none")!, shape: sheetShape))
    .shadow(
      color: .black.opacity(elevation > 0 ? 0.24 : 0),
      radius: elevation,
      y: -elevation / 3)
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
    if rufletModalShouldPresent(
      kind: modalKind,
      open: open,
      lastOpen: lastOpen,
      presented: presented,
      hasContent: hasContent)
    {
      control.updateProperties(["_open": .bool(true)], server: false)
      withAnimation(presentationAnimation) { presented = true }
    } else if !open, lastOpen, presented {
      dismissFromUser()
    }
  }

  private func dismissFromUser() {
    guard presented else { return }
    withAnimation(presentationAnimation) { presented = false }
    dragOffset = 0
    control.updateProperties(["_open": .bool(false)], server: false)
    control.updateProperties(["open": .bool(false)])
    control.triggerEvent("dismiss")
  }

  private var fullscreen: Bool { control.boolean("fullscreen", default: false) }
  private var hasContent: Bool { control.child("content") != nil }
  private var modalKind: RufletModalKind {
    kind == .cupertino ? .cupertinoBottomSheet : .bottomSheet
  }
  private var validationError: String? {
    rufletModalPresentationError(
      kind: modalKind,
      open: control.boolean("open", default: false),
      lastOpen: control.boolean("_open", default: false),
      hasContent: hasContent)
  }
  private var scrollable: Bool {
    fullscreen || control.boolean("scrollable", default: false)
  }
  private var dismissible: Bool {
    kind == .cupertino
      ? !control.boolean("modal", default: false)
      : control.boolean("dismissible", default: true)
  }
  private var draggable: Bool {
    kind == .standard && control.boolean("draggable", default: false)
  }
  private var barrierColor: Color {
    kind == .standard
      ? parseColor(control.string("barrier_color"), .black.opacity(0.54))!
      : .black.opacity(0.54)
  }
  private var elevation: CGFloat {
    CGFloat(max(kind == .standard ? control.number("elevation", default: 0) ?? 0 : 0, 0))
  }
  private var presentationAnimation: Animation {
    parseAnimation(control.dynamicValue("animation_style"))?.animation
      ?? .easeOut(duration: 0.25)
  }
  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: draggable ? 4 : .greatestFiniteMagnitude)
      .onChanged { value in
        guard draggable else { return }
        dragOffset = max(value.translation.height, 0)
      }
      .onEnded { value in
        guard draggable else { return }
        if value.translation.height > 80 || value.predictedEndTranslation.height > 140 {
          dismissFromUser()
        } else {
          withAnimation(presentationAnimation) { dragOffset = 0 }
        }
      }
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

enum RufletModalKind: CaseIterable {
  case alertDialog
  case cupertinoAlertDialog
  case bottomSheet
  case cupertinoBottomSheet

  var missingContentMessage: String {
    switch self {
    case .alertDialog:
      return "AlertDialog has nothing to display. Provide at minimum one of the following: title, content, actions."
    case .cupertinoAlertDialog:
      return "CupertinoAlertDialog has nothing to display. Provide at minimum one of the following: title, content, actions."
    case .bottomSheet:
      return "BottomSheet.content must be visible"
    case .cupertinoBottomSheet:
      // Keep the pinned Flet spelling as part of the renderer contract.
      return "CupertinoButtomSheet.content is empty."
    }
  }

  var validatesBeforePresentation: Bool {
    self != .bottomSheet
  }
}

func rufletModalPresentationError(
  kind: RufletModalKind,
  open: Bool,
  lastOpen: Bool,
  hasContent: Bool
) -> String? {
  guard kind.validatesBeforePresentation, open, open != lastOpen, !hasContent else {
    return nil
  }
  return kind.missingContentMessage
}

func rufletModalShouldPresent(
  kind: RufletModalKind,
  open: Bool,
  lastOpen: Bool,
  presented: Bool,
  hasContent: Bool
) -> Bool {
  // `_open` records that the server-driven opening edge was consumed; it is
  // not presentation state. SwiftUI may legitimately recreate the native
  // presenter while Ruby still owns `open=true`, in which case the modal must
  // rehydrate instead of disappearing. A native dismissal writes `open=false`
  // synchronously, so this cannot reopen a dismissed modal.
  _ = lastOpen
  guard open, !presented else { return false }
  return hasContent || !kind.validatesBeforePresentation
}

private struct RufletSheetClip: ViewModifier {
  let behavior: String
  let shape: RufletCornerShape

  @ViewBuilder
  func body(content: Content) -> some View {
    if behavior.lowercased() == "none" {
      content
    } else {
      content.clipShape(shape)
    }
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
