import RufletProtocol
import SwiftUI

/// Apple-native port of pinned `alert_dialog.dart`.
@MainActor
public struct AlertDialogControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    if rufletIsIOS {
      RufletAppleDialogPresenter(control: control)
    } else {
      ErrorControl("The native AlertDialog renderer requires iOS.")
    }
  }
}

@MainActor
struct RufletAppleDialogPresenter: View {
  @ObservedObject var control: RufletControl
  @State private var presented = false

  private var presentation: RufletAlertDialogPresentation {
    RufletAlertDialogPresentation(control: control)
  }

  var body: some View {
    ZStack {
      RufletPresentationLifecycleAnchor()
      if let validationError {
        ErrorControl(validationError)
      } else if presented {
        dialogLayer.transition(.scale(scale: 1.06).combined(with: .opacity))
      }
    }
    .onAppear(perform: synchronizePresentation)
    .onChange(of: control.revision) { _ in synchronizePresentation() }
  }

  private var dialogLayer: some View {
    ZStack {
      barrier
      dialog
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ignoresSafeArea()
    .zIndex(100)
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
    .modifier(RufletDialogAccessibilityModifier(label: presentation.semanticsLabel))
  }

  private var barrier: some View {
    (parseColor(control.string("barrier_color"))
      ?? Color.black.opacity(0.32))
      .contentShape(Rectangle())
      .onTapGesture {
        if !control.boolean("modal", default: false) { close() }
      }
  }

  private var dialog: some View {
    VStack(spacing: 0) {
      dialogBody
      actionArea
    }
    .padding(EdgeInsets())
    .frame(maxWidth: 270)
    .background { dialogBackground }
    .modifier(
      RufletDialogClipModifier(
        shape: RufletCornerShape(radius: radius),
        behavior: "antialias")
    )
    .overlay {
      if let side = shapeSide {
        RufletCornerShape(radius: radius).stroke(side.color, lineWidth: side.width)
      }
    }
    .shadow(
      color: (parseColor(control.string("shadow_color")) ?? .black)
        .opacity(elevation > 0 ? 0.3 : 0),
      radius: elevation,
      y: elevation / 2
    )
    .padding(
      parsePadding(control.dynamicValue("inset_padding"))
        ?? EdgeInsets(
          top: 24, leading: 36, bottom: 24, trailing: 36)
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: dialogAlignment)
    .contentShape(Rectangle())
  }

  @ViewBuilder
  private var dialogBody: some View {
    let body = VStack(spacing: 0) {
      if let icon = control.buildIconOrWidget("icon", color: iconColor) {
        icon.padding(
          parsePadding(control.dynamicValue("icon_padding"))
            ?? RufletLayoutDefaults.alertDialogIcon(
              hasTitle: control.value("title") != nil,
              hasContent: control.value("content") != nil))
      }
      if let title = control.buildTextOrWidget("title") {
        title
          .modifier(
            RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("title_text_style")))
          )
          .font(.system(size: 17, weight: .semibold))
          .padding(
            parsePadding(control.dynamicValue("title_padding"))
              ?? EdgeInsets(
                top: 18, leading: 20,
                bottom: hasBodyContent ? 2 : 18,
                trailing: 20)
          )
          .frame(maxWidth: .infinity, alignment: .center)
          .multilineTextAlignment(.center)
          .accessibilityAddTraits(.isHeader)
      }
      if let content = control.buildWidget("content") {
        content
          .modifier(
            RufletTextStyleModifier(
              style: parseTextStyle(control.dynamicValue("content_text_style")))
          )
          .font(.system(size: 13))
          .padding(
            parsePadding(control.dynamicValue("content_padding"))
              ?? EdgeInsets(top: 0, leading: 20, bottom: 18, trailing: 20))
          .frame(maxWidth: .infinity, alignment: .center)
          .multilineTextAlignment(.center)
      }
    }

    if control.boolean("scrollable", default: false) {
      ScrollView { body }
    } else {
      body
    }
  }

  private var actionArea: some View {
    VStack(spacing: 0) {
      ForEach(control.children("actions")) { action in
        appleSeparator
        ControlWidget(control: action)
          .frame(maxWidth: .infinity, minHeight: 44)
      }
    }
    .padding(parsePadding(control.dynamicValue("actions_padding")) ?? EdgeInsets())
  }

  private var appleSeparator: some View {
    Divider()
      .overlay(appleSeparatorColor)
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
      withAnimation(dialogAnimation) { presented = true }
    } else if !open, lastOpen, presented {
      close()
    }
  }

  private func close() {
    withAnimation(dialogAnimation) { presented = false }
    control.updateProperties(["_open": .bool(false)], server: false)
    control.updateProperties(["open": .bool(false)])
    control.triggerEvent("dismiss")
  }

  private var hasContent: Bool {
    control.value("title").map { !$0.isNull } ?? false
      || control.value("content").map { !$0.isNull } ?? false
      || !control.children("actions").isEmpty
  }
  private var hasBodyContent: Bool {
    control.value("content").map { !$0.isNull } ?? false
  }
  private var modalKind: RufletModalKind {
    .cupertinoAlertDialog
  }
  private var validationError: String? {
    rufletModalPresentationError(
      kind: modalKind,
      open: control.boolean("open", default: false),
      lastOpen: control.boolean("_open", default: false),
      hasContent: hasContent)
  }
  private var dialogAnimation: Animation {
    parseAnimation(
      control.dynamicValue("inset_animation"),
      ImplicitAnimationDetails(duration: 0.1, curve: .decelerate))!.animation
  }
  private var iconColor: Color? { parseColor(control.string("icon_color")) }
  @ViewBuilder
  private var dialogBackground: some View {
    if let configured = parseColor(control.string("bgcolor")) {
      configured
    } else {
      Rectangle().fill(.regularMaterial)
    }
  }
  private var appleSeparatorColor: Color {
    #if os(iOS)
      Color(uiColor: .separator).opacity(0.65)
    #else
      Color.secondary.opacity(0.3)
    #endif
  }
  private var elevation: Double { max(control.number("elevation", default: 8) ?? 8, 0) }
  private var shapeDetails: [String: Any]? { rufletDictionary(control.dynamicValue("shape")) }
  private var radius: RufletBorderRadius {
    parseBorderRadius(shapeDetails?["radius"])
      ?? RufletBorderRadius(topLeft: 14, topRight: 14, bottomLeft: 14, bottomRight: 14)
  }
  private var shapeSide: RufletBorderSide? { parseBorderSide(shapeDetails?["side"]) }
  private var dialogAlignment: Alignment {
    parseAlignment(control.dynamicValue("alignment"), .center)!.swiftUI
  }
}

@MainActor
struct RufletAlertDialogPresentation {
  let actionButtonPadding: EdgeInsets?
  let clipBehavior: String
  let semanticsLabel: String?

  init(control: RufletControl) {
    actionButtonPadding = parsePadding(control.dynamicValue("action_button_padding"))
    clipBehavior = control.string("clip_behavior", default: "none")!.lowercased()
    semanticsLabel = control.string("semantics_label")
  }

  var clipsContent: Bool { clipBehavior != "none" }
  var antialiasedClip: Bool { clipBehavior.contains("antialias") }
}

private struct RufletDialogClipModifier: ViewModifier {
  let shape: RufletCornerShape
  let behavior: String

  @ViewBuilder
  func body(content: Content) -> some View {
    if behavior == "none" {
      content
    } else {
      content.clipShape(
        shape,
        style: FillStyle(antialiased: behavior.contains("antialias")))
    }
  }
}

private struct RufletDialogAccessibilityModifier: ViewModifier {
  let label: String?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let label {
      content.accessibilityLabel(label)
    } else {
      content
    }
  }
}
