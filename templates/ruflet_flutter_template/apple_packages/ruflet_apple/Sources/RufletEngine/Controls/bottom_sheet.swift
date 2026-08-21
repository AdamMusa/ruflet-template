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

  var body: some View {
    RufletPresentationLifecycleAnchor()
      .sheet(isPresented: $presented, onDismiss: presentationDismissed) {
        nativeSheetContent
      }
      .overlay {
        if let presentationError,
          control.boolean("open", default: false) || presented
        {
          ErrorControl(
            "Native renderer protocol error",
            description: "\(control.type)#\(control.id): \(presentationError)")
        }
      }
      .onAppear(perform: synchronizePresentation)
      .onChange(of: control.revision) { _ in synchronizePresentation() }
  }

  private var nativeSheetContent: some View {
    configuredSheetBody
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .modifier(
        RufletNativeBottomSheetPresentation(
          fullscreen: fullscreen,
          scrollable: scrollable,
          dismissible: dismissible,
          draggable: draggable,
          showDragHandle: control.boolean("show_drag_handle", default: false),
          background: explicitBackground,
          cornerRadius: explicitNativeCornerRadius))
  }

  @ViewBuilder
  private var sheetBody: some View {
    if let content = control.buildWidget("content") {
      if scrollable { ScrollView { content } } else { content }
    } else {
      ErrorControl(modalKind.missingContentMessage)
    }
  }

  private var configuredSheetBody: some View {
    sheetBody
      .frame(
        minWidth: constraint("min_width"),
        maxWidth: constraint("max_width"),
        minHeight: constraint("min_height"),
        maxHeight: constraint("max_height")
      )
      .frame(height: cupertinoPickerHeight)
      .frame(maxWidth: fullscreen ? .infinity : nil, maxHeight: fullscreen ? .infinity : nil)
      .padding(
        kind == .cupertino
          ? parsePadding(control.dynamicValue("padding")) ?? EdgeInsets()
          : EdgeInsets()
      )
      .modifier(
        RufletSheetKeyboardInsets(
          maintains: kind == .cupertino
            || control.boolean("maintain_bottom_view_insets_padding", default: true))
      )
      .modifier(
        RufletSheetSafeArea(
          enabled: kind == .cupertino || control.boolean("use_safe_area", default: true)))
  }

  private func synchronizePresentation() {
    let open = control.boolean("open", default: false)
    let lastOpen = control.boolean("_open", default: false)
    guard presentationError == nil else {
      if presented { presented = false }
      return
    }
    if rufletModalShouldPresent(
      kind: modalKind,
      open: open,
      lastOpen: lastOpen,
      presented: presented,
      hasContent: hasContent)
    {
      control.updateProperties(["_open": .bool(true)], server: false)
      presented = true
    } else if !open, lastOpen, presented {
      dismissFromUser()
    }
  }

  private func dismissFromUser() {
    guard presented else { return }
    presented = false
  }

  private func presentationDismissed() {
    guard
      control.boolean("_open", default: false)
        || control.boolean("open", default: false)
    else { return }
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
  private var presentationError: String? {
    validationError ?? rufletNativeBottomSheetProtocolError(for: control, kind: kind)
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
  private var explicitBackground: Color? {
    parseColor(control.string("bgcolor"))
  }
  private var explicitNativeCornerRadius: CGFloat? {
    guard control.value("shape") != nil else { return nil }
    let radius = parseBorderRadius(rufletDictionary(control.dynamicValue("shape"))?["radius"])
    guard let radius else { return nil }
    return CGFloat(max(radius.topLeft, radius.topRight, 0))
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

@MainActor
func rufletNativeBottomSheetProtocolError(
  for control: RufletControl,
  kind: RufletAppleSheetPresenter.Kind
) -> String? {
  func hasValue(_ name: String) -> Bool {
    guard let value = control.value(name) else { return false }
    return !value.isNull
  }

  for property in ["barrier_color", "elevation", "animation_style"] where hasValue(property) {
    return "\(property) cannot be applied by the public Apple sheet API"
  }
  if let clip = control.value("clip_behavior") {
    guard let value = clip.text?.lowercased(), value == "none" else {
      return "clip_behavior must be none because Apple owns native sheet clipping"
    }
  }
  if hasValue("bgcolor"), parseColor(control.string("bgcolor")) == nil {
    return "bgcolor is not a valid protocol color"
  }
  if let rawShape = control.dynamicValue("shape") {
    guard let shape = rufletDictionary(rawShape) else {
      return "shape must be a protocol shape map"
    }
    if shape["side"] != nil {
      return "shape.side cannot be applied by the public Apple sheet API"
    }
    if let rawRadius = shape["radius"] {
      guard let radius = parseBorderRadius(rawRadius) else {
        return "shape.radius is not a valid protocol border radius"
      }
      let values = [radius.topLeft, radius.topRight, radius.bottomLeft, radius.bottomRight]
      guard values.dropFirst().allSatisfy({ abs($0 - values[0]) < 0.001 }) else {
        return "shape.radius must be uniform for a native Apple sheet"
      }
    }
  }
  if let rawConstraints = control.dynamicValue("size_constraints") {
    guard let constraints = rufletDictionary(rawConstraints) else {
      return "size_constraints must be a protocol constraint map"
    }
    for name in ["min_width", "max_width", "min_height", "max_height"] {
      guard let rawValue = constraints[name] else { continue }
      guard let value = parseDouble(rawValue), value.isFinite, value >= 0 else {
        return "size_constraints.\(name) must be a finite non-negative number"
      }
    }
  }

  #if os(macOS)
    if hasValue("bgcolor") {
      return "bgcolor cannot be applied to the native macOS sheet window"
    }
    if hasValue("shape") {
      return "shape cannot be applied to the native macOS sheet window"
    }
    if control.boolean("fullscreen", default: false) {
      return "fullscreen is not a native macOS bottom-sheet presentation"
    }
    if kind == .standard, control.boolean("draggable", default: false) {
      return "draggable is not supported by the native macOS sheet presentation"
    }
    if kind == .standard, control.boolean("show_drag_handle", default: false) {
      return "show_drag_handle is not supported by the native macOS sheet presentation"
    }
  #else
    _ = kind
  #endif

  return nil
}

/// Uses SwiftUI's public Apple sheet presentation. Ruflet supplies protocol
/// content and supported preferences; the OS owns chrome, motion and gestures.
private struct RufletNativeBottomSheetPresentation: ViewModifier {
  let fullscreen: Bool
  let scrollable: Bool
  let dismissible: Bool
  let draggable: Bool
  let showDragHandle: Bool
  let background: Color?
  let cornerRadius: CGFloat?

  @ViewBuilder
  func body(content: Content) -> some View {
    #if os(iOS)
      if #available(iOS 18.0, *) {
        if fullscreen {
          chrome(content).presentationSizing(.page)
        } else {
          chrome(content).presentationSizing(.fitted)
        }
      } else if fullscreen {
        chrome(content).presentationDetents([.large])
      } else if scrollable {
        chrome(content).presentationDetents([.medium, .large])
      } else {
        chrome(content).presentationDetents([.medium])
      }
    #else
      content.interactiveDismissDisabled(!dismissible)
    #endif
  }

  #if os(iOS)
    @ViewBuilder
    private func chrome(_ content: Content) -> some View {
      if #available(iOS 16.4, *) {
        if let background, let cornerRadius {
          common(content)
            .presentationBackground(background)
            .presentationCornerRadius(cornerRadius)
        } else if let background {
          common(content).presentationBackground(background)
        } else if let cornerRadius {
          common(content).presentationCornerRadius(cornerRadius)
        } else {
          common(content)
        }
      } else {
        common(content).background((background ?? Color.rufletSystemBackground).ignoresSafeArea())
      }
    }

    private func common(_ content: Content) -> some View {
      content
        .presentationDragIndicator(showDragHandle ? .visible : .hidden)
        .interactiveDismissDisabled(!dismissible || !draggable)
    }
  #endif
}

enum RufletModalKind: CaseIterable {
  case alertDialog
  case cupertinoAlertDialog
  case bottomSheet
  case cupertinoBottomSheet

  var missingContentMessage: String {
    switch self {
    case .alertDialog:
      return
        "AlertDialog has nothing to display. Provide at minimum one of the following: title, content, actions."
    case .cupertinoAlertDialog:
      return
        "CupertinoAlertDialog has nothing to display. Provide at minimum one of the following: title, content, actions."
    case .bottomSheet:
      return "BottomSheet.content must be visible"
    case .cupertinoBottomSheet:
      // Keep the pinned Flet spelling as part of the renderer contract.
      return "CupertinoButtomSheet.content is empty."
    }
  }

  var validatesBeforePresentation: Bool {
    true
  }
}

func rufletModalPresentationError(
  kind: RufletModalKind,
  open: Bool,
  lastOpen: Bool,
  hasContent: Bool
) -> String? {
  _ = lastOpen
  guard kind.validatesBeforePresentation, open, !hasContent else {
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
