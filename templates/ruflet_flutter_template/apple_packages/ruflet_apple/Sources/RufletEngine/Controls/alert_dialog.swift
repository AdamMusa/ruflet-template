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
    RufletAppleDialogPresenter(control: control, style: .standard)
  }
}

@MainActor
struct RufletAppleDialogPresenter: View {
  enum Style { case standard, cupertino }

  @ObservedObject var control: RufletControl
  let style: Style
  @State private var presented = false

  private var presentation: RufletAlertDialogPresentation {
    RufletAlertDialogPresentation(control: control)
  }

  var body: some View {
    Group {
      if let validationError {
        ErrorControl(validationError)
      } else if presented {
        dialogLayer.transition(.opacity)
      }
    }
    .onAppear(perform: synchronizePresentation)
    .onChange(of: control.properties) { _ in synchronizePresentation() }
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
    (parseColor(control.string("barrier_color")) ?? Color.black.opacity(0.54))
      .contentShape(Rectangle())
      .onTapGesture {
        if !control.boolean("modal", default: false) { close() }
      }
  }

  private var dialog: some View {
    VStack(spacing: style == .cupertino ? 0 : 12) {
      dialogBody
      actionArea
    }
    .padding(style == .cupertino ? EdgeInsets() : dialogPadding)
    .frame(maxWidth: style == .cupertino ? 320 : 560)
    .background(parseColor(control.string("bgcolor")) ?? Color.rufletSystemBackground)
    .modifier(
      RufletDialogClipModifier(
        shape: RufletCornerShape(radius: radius),
        behavior: style == .cupertino ? "antialias" : presentation.clipBehavior)
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
          top: 24, leading: style == .cupertino ? 36 : 40, bottom: 24,
          trailing: style == .cupertino ? 36 : 40)
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: dialogAlignment)
    .contentShape(Rectangle())
  }

  @ViewBuilder
  private var dialogBody: some View {
    let body = VStack(spacing: 10) {
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
          .font(style == .cupertino ? .headline : .title3.weight(.semibold))
          .padding(
            style == .cupertino
              ? EdgeInsets(top: 20, leading: 20, bottom: 6, trailing: 20)
              : parsePadding(control.dynamicValue("title_padding"))
                ?? RufletLayoutDefaults.alertDialogTitle(
                  hasIcon: control.value("icon") != nil,
                  hasContent: control.value("content") != nil)
          )
          .accessibilityAddTraits(.isHeader)
      }
      if let content = control.buildWidget("content") {
        content
          .modifier(
            RufletTextStyleModifier(
              style: parseTextStyle(control.dynamicValue("content_text_style")))
          )
          .padding(
            style == .cupertino
              ? EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20)
              : parsePadding(control.dynamicValue("content_padding"))
                ?? EdgeInsets(top: 20, leading: 24, bottom: 24, trailing: 24))
      }
    }

    if control.boolean("scrollable", default: false) {
      ScrollView { body }
    } else {
      body
    }
  }

  @ViewBuilder
  private var actionArea: some View {
    if style == .cupertino {
      VStack(spacing: 0) {
        ForEach(control.children("actions")) { action in
          Divider()
          ControlWidget(control: action)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
      }
    } else {
      HStack(spacing: control.number("actions_overflow_button_spacing") ?? 8) {
        ForEach(control.children("actions")) { action in
          ControlWidget(control: action)
            .padding(presentation.actionButtonPadding ?? RufletLayoutDefaults.alertDialogActionButton)
        }
      }
      .frame(maxWidth: .infinity, alignment: actionsAlignment)
      .padding(
        parsePadding(control.dynamicValue("actions_padding"))
          ?? RufletLayoutDefaults.alertDialogActions)
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
  private var modalKind: RufletModalKind {
    style == .cupertino ? .cupertinoAlertDialog : .alertDialog
  }
  private var validationError: String? {
    rufletModalPresentationError(
      kind: modalKind,
      open: control.boolean("open", default: false),
      lastOpen: control.boolean("_open", default: false),
      hasContent: hasContent)
  }
  private var dialogAnimation: Animation {
    if style == .cupertino {
      return parseAnimation(
        control.dynamicValue("inset_animation"),
        ImplicitAnimationDetails(duration: 0.1, curve: .decelerate))!.animation
    }
    return .easeOut(duration: 0.15)
  }
  private var dialogPadding: EdgeInsets { EdgeInsets() }
  private var iconColor: Color? { parseColor(control.string("icon_color")) }
  private var elevation: Double { max(control.number("elevation", default: 8) ?? 8, 0) }
  private var shapeDetails: [String: Any]? { rufletDictionary(control.dynamicValue("shape")) }
  private var radius: RufletBorderRadius {
    if style == .cupertino {
      return RufletBorderRadius(topLeft: 14, topRight: 14, bottomLeft: 14, bottomRight: 14)
    }
    return parseBorderRadius(
      shapeDetails?["radius"],
      RufletBorderRadius(topLeft: 14, topRight: 14, bottomLeft: 14, bottomRight: 14))!
  }
  private var shapeSide: RufletBorderSide? { parseBorderSide(shapeDetails?["side"]) }
  private var dialogAlignment: Alignment {
    parseAlignment(control.dynamicValue("alignment"), .center)!.swiftUI
  }
  private var actionsAlignment: Alignment {
    switch control.string("actions_alignment")?.lowercased() {
    case "start": .leading
    case "center": .center
    case "spacebetween", "spacearound", "spaceevenly": .center
    default: .trailing
    }
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
