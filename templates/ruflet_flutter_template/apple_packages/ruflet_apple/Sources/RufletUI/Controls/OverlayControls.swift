import RufletEngine
import RufletProtocol
import SwiftUI

/// Presents everything hanging off `page._dialogs`.
///
/// Ruflet keeps dialogs, sheets and snack bars in one container control and
/// drives them by flipping each one's `open` prop (`Page#show_dialog` /
/// `#close_dialog`). The renderer therefore watches that container rather than
/// the layout tree, and reports `dismiss` when the user closes something
/// themselves — which is what lets `Page#dispatch_event` drop it from its own
/// list.
struct DialogPresenter: ViewModifier {
  let host: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .center) { modalLayer }
      .overlay(alignment: .top) { bannerLayer }
      .overlay(alignment: .bottom) { snackBarLayer }
      .animation(.easeOut(duration: 0.2), value: store.revision)
  }

  private var openDialogs: [ControlNode] {
    guard let dialogsID = store.page?.controlID(forKey: "_dialogs"),
      let container = store.node(dialogsID)
    else { return [] }
    return container.childIDs
      .compactMap { store.node($0) }
      .filter { $0.bool("open") == true }
  }

  /// Alerts and bottom sheets take over the screen; the last one
  /// opened is on top, matching a navigator stack.
  @ViewBuilder
  private var modalLayer: some View {
    let modals = openDialogs.filter { $0.type != "SnackBar" && $0.type != "Banner" }
    if let dialog = modals.last {
      ZStack {
        // `modal` keeps the barrier from dismissing, and `barrier_color`
        // paints it — both are the dialog's own properties in Flet.
        AppleChromeAppearance.color(
          dialog.string("barrier_color"), fallback: RufletOverlaySemantics.defaultBarrierColor(dialog))
          .ignoresSafeArea()
          .onTapGesture {
            guard RufletOverlaySemantics.allowsBarrierDismiss(dialog) else { return }
            dismiss(dialog, barrierDismiss: true)
          }
        modalBody(dialog)
      }
      .transition(.opacity)
    }
  }

  @ViewBuilder
  private func modalBody(_ dialog: ControlNode) -> some View {
    switch dialog.type {
    case "BottomSheet", "CupertinoBottomSheet":
      VStack {
        Spacer(minLength: 0)
        BottomSheetControlView(node: dialog)
      }
      .transition(.move(edge: .bottom))
    case "DatePicker":
      DateTimePickerControlView(node: dialog, kind: .date)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    case "DateRangePicker":
      DateTimePickerControlView(node: dialog, kind: .dateRange)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    case "TimePicker":
      DateTimePickerControlView(node: dialog, kind: .time)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    default:
      AlertDialogControlView(node: dialog)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }
  }

  /// Material banners are persistent page chrome, not dialogs: they sit below
  /// the app bar and never dim or disable the page behind them.
  @ViewBuilder
  private var bannerLayer: some View {
    if let banner = openDialogs.last(where: { $0.type == "Banner" }) {
      BannerControlView(node: banner)
        .padding(.top, appBarHeight)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
  }

  private var appBarHeight: CGFloat {
    guard let appBarID = host.controlID(forKey: "appbar"), let appBar = store.node(appBarID) else {
      return 0
    }
    return ChromeDefaults.appBar(appBar).toolbarHeight
  }

  @ViewBuilder
  private var snackBarLayer: some View {
    if let snackBar = openDialogs.last(where: { $0.type == "SnackBar" }) {
      SnackBarControlView(node: snackBar)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
  }

  /// Tapping the scrim closes a dialog unless Ruby set `modal`.
  private func dismiss(_ dialog: ControlNode, barrierDismiss: Bool) {
    guard !barrierDismiss || RufletOverlaySemantics.allowsBarrierDismiss(dialog) else { return }
    if ["DatePicker", "DateRangePicker", "TimePicker"].contains(dialog.type) {
      RufletPickerEvents.cancel(dialog, to: events)
      return
    }
    events.setLocal(dialog.id, "open", .bool(false))
    events.update(dialog.id, ["open": .bool(false)])
    events.fire(dialog, "dismiss")
  }
}

/// Presentation decisions shared by the overlay host and the concrete views.
/// Keeping them explicit prevents Apple platform defaults from silently
/// changing Flet's design-family and dismissal contracts.
enum RufletOverlaySemantics {
  /// Material's `showDialog` fallback is `Colors.black54`. Keep that exact
  /// constructor default for the three Flet picker services while leaving the
  /// pre-existing fallback for other overlay families untouched.
  static func defaultBarrierOpacity(_ node: ControlNode) -> Double {
    ["DatePicker", "DateRangePicker", "TimePicker"].contains(node.type) ? 0.54 : 0.3
  }

  static func defaultBarrierColor(_ node: ControlNode) -> Color {
    .black.opacity(defaultBarrierOpacity(node))
  }

  /// This package is the Apple renderer, so an omitted `adaptive` flag still
  /// resolves to native Apple presentation. The flag remains on the wire for
  /// cross-platform clients; it is not a request for Material visuals here.
  static func usesNativeAppleDialog(_ node: ControlNode) -> Bool { true }

  static func usesCupertinoDialog(_ node: ControlNode) -> Bool {
    node.type == "CupertinoAlertDialog" || node.bool("adaptive") == true
  }

  static func hasExplicitDialogAppearance(_ node: ControlNode) -> Bool {
    [
      "alignment", "bgcolor", "shape", "elevation", "shadow_color", "clip_behavior",
      "inset_padding", "icon_padding", "title_padding", "content_padding",
      "actions_padding", "action_button_padding", "actions_alignment",
    ].contains { node.props[$0] != nil }
  }

  static func allowsBarrierDismiss(_ node: ControlNode) -> Bool {
    switch node.type {
    case "BottomSheet":
      return node.bool("dismissible") != false
    case "CupertinoBottomSheet":
      return node.bool("modal") != true
    default:
      return node.bool("modal") != true
    }
  }

  static func dismiss(_ node: ControlNode, through events: RufletEventSink) {
    events.setLocal(node.id, "open", .bool(false))
    events.update(node.id, ["open": .bool(false)])
    events.fire(node, "dismiss")
  }
}

/// Native Apple presentation defaults. Explicit DSL values remain the source
/// of truth; omitted appearance values inherit Apple geometry instead of
/// silently importing Flutter Material theme constants.
enum OverlayDefaults {
  struct DialogValues: Equatable {
    let radius: CGFloat
    let elevation: CGFloat
    let inset: EdgeInsets
    let content: EdgeInsets
    let actions: EdgeInsets
  }

  struct SheetValues: Equatable {
    let radius: CGFloat
    let elevation: CGFloat
    let maximumWidth: CGFloat?
    let dragHandleWidth: CGFloat
    let dragHandleHeight: CGFloat
    let useSafeArea: Bool
    let dismissible: Bool
  }

  struct SnackBarValues: Equatable {
    let elevation: CGFloat
    let radius: CGFloat
    let horizontalPadding: CGFloat
    let inset: EdgeInsets
    let durationMilliseconds: Double
    let dismissDirection: String
    let actionOverflowThreshold: Double
  }

  static func dialog(_ node: ControlNode) -> DialogValues {
    DialogValues(
      radius: ControlProps.cornerRadius(node.map("shape")?["radius"]) ?? 14,
      elevation: CGFloat(node.double("elevation") ?? 0),
      inset: ControlProps.edgeInsets(node.props["inset_padding"])
        ?? EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
      content: ControlProps.edgeInsets(node.props["content_padding"])
        ?? EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20),
      actions: ControlProps.edgeInsets(node.props["actions_padding"])
        ?? EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
  }

  static func sheet(_ node: ControlNode) -> SheetValues {
    SheetValues(
      radius: ControlProps.cornerRadius(node.map("shape")?["radius"]) ?? 16,
      elevation: CGFloat(node.double("elevation") ?? 0),
      maximumWidth: nil,
      dragHandleWidth: 36, dragHandleHeight: 5,
      useSafeArea: node.bool("use_safe_area") != false,
      dismissible: node.bool("dismissible") != false)
  }

  static func snackBar(_ node: ControlNode) -> SnackBarValues {
    return SnackBarValues(
      elevation: CGFloat(node.double("elevation") ?? 0),
      radius: ControlProps.cornerRadius(node.map("shape")?["radius"]) ?? 12,
      horizontalPadding: 16,
      inset: ControlProps.edgeInsets(node.props["margin"])
        ?? EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
      durationMilliseconds: node.double("duration") ?? 4000,
      dismissDirection: node.string("dismiss_direction")?.lowercased() ?? "down",
      actionOverflowThreshold: node.double("action_overflow_threshold") ?? 0.25)
  }

  static func bannerContentPadding(_ node: ControlNode) -> EdgeInsets {
    if let explicit = ControlProps.edgeInsets(node.props["content_padding"]) { return explicit }
    return EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
  }
}

/// `AlertDialog` — title, content and actions.
struct AlertDialogControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  @ViewBuilder
  var body: some View {
    if !hasAlertContent
    {
      Text("AlertDialog has nothing to display. Provide icon, title, content, or actions.")
        .foregroundColor(.red)
    } else if RufletOverlaySemantics.usesNativeAppleDialog(node)
        && (node.type == "CupertinoAlertDialog"
          || !RufletOverlaySemantics.hasExplicitDialogAppearance(node))
    {
      appleAlert
    } else {
      styledDialog
    }
  }

  private var styledDialog: some View {
    let defaults = OverlayDefaults.dialog(node)
    let hasTitle = node.controlID(forKey: "title") != nil
    let hasContent = node.controlID(forKey: "content") != nil
    let body = VStack(alignment: .leading, spacing: 0) {
      if node.controlID(forKey: "icon") != nil {
        RufletFormFieldSlot(node: node, key: "icon")
          .foregroundColor(MaterialPalette.color(node.string("icon_color"), default:
            .secondary))
          .frame(maxWidth: .infinity)
          .padding(ControlProps.edgeInsets(node.props["icon_padding"]) ?? EdgeInsets(
            top: 24, leading: 24, bottom: hasTitle ? 16 : (hasContent ? 0 : 24), trailing: 24))
      }
      if let titleID = node.controlID(forKey: "title") {
        ControlView(id: titleID, axis: .none)
          .rufletTextStyle(RufletTextStyle(node: node, styleKey: "title_text_style"))
          .padding(ControlProps.edgeInsets(node.props["title_padding"]) ?? EdgeInsets(
            top: node.controlID(forKey: "icon") == nil ? 24 : 0,
            leading: 24, bottom: hasContent ? 0 : 20, trailing: 24))
      }
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .vertical)
          .rufletTextStyle(RufletTextStyle(node: node, styleKey: "content_text_style"))
          .padding(defaults.content)
      }
      if !node.controlIDs(forKey: "actions").isEmpty {
        HStack(spacing: CGFloat(node.double("actions_overflow_button_spacing") ?? 8)) {
          if actionsAlignment != .leading { Spacer(minLength: 0) }
          ControlList(ids: node.controlIDs(forKey: "actions"), axis: .horizontal)
            .padding(ControlProps.edgeInsets(node.props["action_button_padding"]) ?? EdgeInsets())
          if actionsAlignment == .leading { Spacer(minLength: 0) }
        }
        .padding(defaults.actions)
      }
    }
    .frame(maxWidth: 420)
    .background(
      RoundedRectangle(cornerRadius: defaults.radius)
        .fill(MaterialPalette.color(node.string("bgcolor"), default: dialogSurface)))
    .shadow(
      color: AppleChromeAppearance.color(node.string("shadow_color"), fallback: .clear),
      radius: defaults.elevation)
    .padding(defaults.inset)
    .modifier(DialogClip(radius: defaults.radius, behavior: node.string("clip_behavior") ?? "none"))

    // `scrollable` lets a tall dialog scroll rather than overflow, which is
    // what Material's AlertDialog does with the same flag.
    return Group {
      if node.bool("scrollable") == true {
        ScrollView { body }
      } else {
        body
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: dialogAlignment)
    .modifier(OptionalAccessibilityLabel(value: node.string("semantics_label")))
  }

  /// `actions_alignment` is Flutter's MainAxisAlignment across the button row.
  private var actionsAlignment: HorizontalAlignment {
    switch node.string("actions_alignment")?.lowercased() {
    case "start", "spacebetween": return .leading
    case "center": return .center
    default: return .trailing
    }
  }

  private var dialogAlignment: Alignment {
    ControlProps.alignment(node.props["alignment"]) ?? .center
  }

  private var appleAlert: some View {
    VStack(spacing: 0) {
      if let iconID = node.controlID(forKey: "icon") {
        ControlView(id: iconID, axis: .none)
          .foregroundColor(AppleChromeAppearance.color(
            node.string("icon_color"), fallback: .accentColor))
          .frame(maxWidth: .infinity)
          .padding(ControlProps.edgeInsets(node.props["icon_padding"])
            ?? EdgeInsets(top: 18, leading: 20, bottom: 4, trailing: 20))
      }
      if node.props["title"] != nil {
        appleTextOrWidget("title")
          .font(.system(size: 17, weight: .semibold))
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
          .padding(.horizontal, 20)
          .padding(.top, 20)
          .padding(.bottom, node.controlID(forKey: "content") == nil ? 20 : 1)
      }
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .vertical)
          .font(.system(size: 13))
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
          .padding(.horizontal, 20)
          .padding(.top, node.controlID(forKey: "title") == nil ? 20 : 1)
          .padding(.bottom, 20)
      }

      let actionIDs = node.controlIDs(forKey: "actions")
      if !actionIDs.isEmpty {
        Divider()
        if actionIDs.count <= 2 {
          HStack(spacing: 0) {
            ForEach(Array(actionIDs.enumerated()), id: \.element) { index, actionID in
              if index > 0 { Divider() }
              appleAction(actionID)
            }
          }
          .frame(height: 44)
        } else {
          VStack(spacing: 0) {
            ForEach(Array(actionIDs.enumerated()), id: \.element) { index, actionID in
              if index > 0 { Divider() }
              appleAction(actionID).frame(height: 44)
            }
          }
        }
      }
    }
    .frame(width: 270)
    .background {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(.regularMaterial)
        .overlay {
          if node.props["bgcolor"] != nil {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(AppleChromeAppearance.color(node.string("bgcolor"), fallback: .clear))
          }
        }
    }
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .shadow(
      color: AppleChromeAppearance.color(node.string("shadow_color"), fallback: .clear),
      radius: CGFloat(node.double("elevation") ?? 0))
  }

  @ViewBuilder
  private func appleAction(_ actionID: Int) -> some View {
    if let action = store.node(actionID) {
      Button {
        guard action.bool("disabled") != true else { return }
        events.fire(action, "click")
      } label: {
        appleActionContent(action)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .buttonStyle(.plain)
      .font(.system(
        size: 16.8,
        weight: RufletCupertinoPresentationDefaults.isDefaultAction(action)
          ? .semibold : .regular))
      .foregroundColor(
        RufletCupertinoPresentationDefaults.isDestructiveAction(action)
          ? .red : .accentColor)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .disabled(action.bool("disabled") ?? false)
    }
  }

  @ViewBuilder
  private func appleActionContent(_ action: ControlNode) -> some View {
    if let contentID = action.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    } else if let text = action.string("content") {
      Text(text)
    } else {
      Text("content must be provided").foregroundColor(.red)
    }
  }

  @ViewBuilder
  private func appleTextOrWidget(_ key: String) -> some View {
    if let contentID = node.controlID(forKey: key) {
      ControlView(id: contentID, axis: .none)
    } else if let text = node.string(key) {
      Text(text)
    }
  }

  private var hasAlertContent: Bool {
    node.controlID(forKey: "icon") != nil
      || RufletCupertinoPresentationDefaults.hasAlertContent(node)
  }

  private var dialogSurface: Color {
    AppleChromeAppearance.barSurface
  }
}

private struct DialogClip: ViewModifier {
  let radius: CGFloat
  let behavior: String

  func body(content: Content) -> some View {
    if behavior.lowercased() == "none" {
      content
    } else {
      content.clipShape(RoundedRectangle(cornerRadius: radius))
    }
  }
}

private struct OptionalAccessibilityLabel: ViewModifier {
  let value: String?

  func body(content: Content) -> some View {
    if let value, !value.isEmpty {
      content.accessibilityLabel(Text(value))
    } else {
      content
    }
  }
}

/// `BottomSheet` — content anchored to the bottom edge.
struct BottomSheetControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  @ViewBuilder
  var body: some View {
    if node.type == "CupertinoBottomSheet" {
      cupertinoSheet
    } else {
      nativeSheet
    }
  }

  private var nativeSheet: some View {
    let defaults = OverlayDefaults.sheet(node)
    let content = VStack(spacing: 0) {
      if node.bool("show_drag_handle") == true {
        Capsule()
          .fill(Color.secondary)
          .frame(width: defaults.dragHandleWidth, height: defaults.dragHandleHeight)
          .frame(height: 44)
      }
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .vertical)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(maxHeight: node.bool("fullscreen") == true ? .infinity : nil)
    .background(
      MaterialPalette.color(node.string("bgcolor"), default: sheetSurface),
      in: UnevenRoundedRectangle(
        topLeadingRadius: defaults.radius, bottomLeadingRadius: 0,
        bottomTrailingRadius: 0, topTrailingRadius: defaults.radius))
    .overlay(
      UnevenRoundedRectangle(
        topLeadingRadius: defaults.radius, bottomLeadingRadius: 0,
        bottomTrailingRadius: 0, topTrailingRadius: defaults.radius)
        .strokeBorder(
          MaterialPalette.color(node.map("shape")?["side"]?.mapValue?["color"]?.stringValue,
                                default: .clear),
          lineWidth: CGFloat(
            node.map("shape")?["side"]?.mapValue?["width"]?.doubleValue ?? 0)))
    .shadow(
      color: MaterialPalette.color(node.string("shadow_color"), default: .clear),
      radius: defaults.elevation)
    .frame(maxWidth: node.bool("fullscreen") == true ? nil : defaults.maximumWidth)
    .modifier(SlotSizeConstraints(value: node.props["size_constraints"]))
    .modifier(ChromeClipModifier(behavior: node.string("clip_behavior") ?? "none"))
    .modifier(BottomSheetDrag(node: node, events: events))

    return Group {
      if node.bool("scrollable") == true || node.bool("fullscreen") == true {
        ScrollView { content }
      } else {
        content
      }
    }
    .modifier(BottomSheetSafeArea(useSafeArea: defaults.useSafeArea))
  }

  @ViewBuilder
  private var cupertinoSheet: some View {
    if let contentID = node.controlID(forKey: "content") {
      if let content = store.node(contentID), Self.cupertinoPickerTypes.contains(content.type) {
        ControlView(id: contentID, axis: .vertical)
          .frame(maxWidth: .infinity)
          .frame(height: CGFloat(node.double("height")
            ?? Double(RufletCupertinoPresentationDefaults.bottomSheetPickerHeight)))
          .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets())
          .background(MaterialPalette.color(node.string("bgcolor"), default: cupertinoSheetSurface))
      } else {
        // Flet intentionally wraps arbitrary Cupertino sheet content in a
        // Material widget but adds no BottomSheet surface, shape or padding.
        ControlView(id: contentID, axis: .vertical)
      }
    }
  }

  private static let cupertinoPickerTypes: Set<String> = [
    "CupertinoPicker", "CupertinoTimerPicker", "CupertinoDatePicker",
  ]

  private var sheetSurface: Color {
    AppleChromeAppearance.barSurface
  }

  private var cupertinoSheetSurface: Color {
    #if canImport(UIKit)
      return Color(UIColor.systemBackground)
    #elseif canImport(AppKit)
      return Color(NSColor.windowBackgroundColor)
    #else
      return .white
    #endif
  }
}

private struct BottomSheetSafeArea: ViewModifier {
  let useSafeArea: Bool

  func body(content: Content) -> some View {
    if useSafeArea {
      content
    } else {
      content.ignoresSafeArea()
    }
  }
}

private struct BottomSheetDrag: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    guard node.bool("draggable") == true else { return AnyView(content) }
    return AnyView(
      content.simultaneousGesture(
        DragGesture(minimumDistance: 12).onEnded { value in
          guard value.translation.height > 50,
            abs(value.translation.height) > abs(value.translation.width)
          else { return }
          RufletOverlaySemantics.dismiss(node, through: events)
        }))
  }
}

/// `dismiss_direction` is the way a snack bar can be swiped away.
private struct SnackBarSwipe: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    let direction = OverlayDefaults.snackBar(node).dismissDirection
    guard direction != "none" else { return AnyView(content) }
    return AnyView(
      content.gesture(
        DragGesture(minimumDistance: 20).onEnded { value in
          let horizontal = abs(value.translation.width) > abs(value.translation.height)
          let matches: Bool
          switch direction {
          case "up": matches = !horizontal && value.translation.height < 0
          case "down": matches = !horizontal && value.translation.height > 0
          case "starttoend": matches = horizontal && value.translation.width > 0
          case "endtostart": matches = horizontal && value.translation.width < 0
          case "horizontal": matches = horizontal
          case "vertical": matches = !horizontal
          default: matches = true
          }
          if matches { RufletOverlaySemantics.dismiss(node, through: events) }
        }))
  }
}

/// `SnackBar` — a transient message with an optional action.
struct SnackBarControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let defaults = OverlayDefaults.snackBar(node)
    HStack(spacing: 12) {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
      Spacer(minLength: 0)
      if let actionID = node.controlID(forKey: "action") {
        ControlView(id: actionID, axis: .none)
      } else if let action = node.string("action") {
        Button(action) { events.fire(node, "action") }
      }
      // Flutter offers a close affordance when the bar is not transient.
      if node.bool("show_close_icon") == true {
        Button {
          RufletOverlaySemantics.dismiss(node, through: events)
        } label: {
          Image(systemName: "xmark")
            .foregroundColor(
              AppleChromeAppearance.color(node.string("close_icon_color"), fallback: .secondary))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(ControlProps.edgeInsets(node.props["padding"])
      ?? EdgeInsets(
        top: 14, leading: defaults.horizontalPadding,
        bottom: 14,
        trailing: node.controlID(forKey: "action") != nil
          || node.string("action") != nil || node.bool("show_close_icon") == true
          ? 0 : defaults.horizontalPadding))
    .background {
      RoundedRectangle(cornerRadius: defaults.radius, style: .continuous)
        .fill(.regularMaterial)
        .overlay {
          if node.props["bgcolor"] != nil {
            RoundedRectangle(cornerRadius: defaults.radius, style: .continuous)
              .fill(AppleChromeAppearance.color(node.string("bgcolor"), fallback: .clear))
          }
        }
    }
    .modifier(ChromeClipModifier(behavior: node.string("clip_behavior") ?? "hardEdge"))
    .shadow(
      color: AppleChromeAppearance.color(node.string("shadow_color"), fallback: .clear),
      radius: defaults.elevation)
    .frame(width: floating ? node.double("width").map { CGFloat($0) } : nil)
    .foregroundColor(.primary)
    .padding(floating ? floatingInsets(defaults) : defaults.inset)
    .modifier(SnackBarSwipe(node: node, events: events))
    // Flutter's SnackBar invokes `onVisible` when the presentation becomes
    // visible. The action click stays on SnackBarAction when it is a control;
    // the string shorthand reports `action` on the SnackBar above.
    .onAppear { events.fire(node, "visible") }
    .task(id: node.id) { await autoDismiss() }
  }

  private var floating: Bool { node.string("behavior")?.lowercased() == "floating" }

  private func floatingInsets(_ defaults: OverlayDefaults.SnackBarValues) -> EdgeInsets {
    // Flutter ignores horizontal margin when an explicit floating width is
    // supplied, but preserves the vertical inset.
    guard node.double("width") != nil else { return defaults.inset }
    return EdgeInsets(top: defaults.inset.top, leading: 0, bottom: defaults.inset.bottom, trailing: 0)
  }

  /// Flet's SnackBar hides itself after `duration` milliseconds; the Ruby side
  /// only learns about it through the `dismiss` event, so send one. `persist`
  /// keeps it up until something dismisses it, and the overflow threshold
  /// decides when the action moves to its own line.
  private func autoDismiss() async {
    guard node.bool("persist") != true else { return }
    let milliseconds = OverlayDefaults.snackBar(node).durationMilliseconds
    guard milliseconds > 0 else { return }
    try? await Task.sleep(nanoseconds: UInt64(milliseconds * 1_000_000))
    guard !Task.isCancelled else { return }
    RufletOverlaySemantics.dismiss(node, through: events)
  }
}

/// `Banner` — a persistent message strip below the app bar.
struct BannerControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let singleRow = node.controlIDs(forKey: "actions").count == 1
      && node.bool("force_actions_below") != true
    let elevation = CGFloat(node.double("elevation") ?? 0)
    VStack(spacing: 0) {
      HStack(alignment: .center, spacing: 0) {
        if let leadingID = node.controlID(forKey: "leading") {
          ControlView(id: leadingID, axis: .none)
            .padding(ControlProps.edgeInsets(node.props["leading_padding"])
              ?? EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
        }
        bannerContent
        if singleRow { actionBar }
      }
      .padding(OverlayDefaults.bannerContentPadding(node))
      if !singleRow { actionBar }
      if elevation == 0 {
        Rectangle()
          .fill(AppleChromeAppearance.color(
            node.string("divider_color"), fallback: AppleChromeAppearance.separator))
          .frame(height: 1)
      }
    }
    .frame(maxWidth: .infinity)
    .background(AppleChromeAppearance.color(
      node.string("bgcolor"), fallback: AppleChromeAppearance.barSurface))
    .shadow(
      color: AppleChromeAppearance.color(node.string("shadow_color"), fallback: .clear),
      radius: elevation)
    .padding(ControlProps.edgeInsets(node.props["margin"])
      ?? EdgeInsets(top: 0, leading: 0, bottom: elevation > 0 ? 10 : 0, trailing: 0))
    .onAppear { events.fire(node, "visible") }
  }

  @ViewBuilder
  private var bannerContent: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
        .rufletTextStyle(RufletTextStyle(node: node, styleKey: "content_text_style"))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var actionBar: some View {
    HStack(spacing: 8) {
      Spacer(minLength: 0)
      ControlList(ids: node.controlIDs(forKey: "actions"), axis: .horizontal)
    }
    .padding(.horizontal, 8)
    .frame(minHeight: CGFloat(node.double("min_action_bar_height") ?? 44))
  }
}

/// Presents `page.drawer` and `page.end_drawer`.
///
/// The Ruby side opens these by invoking `show_drawer` on the page rather than
/// by patching a prop, so the engine's page service writes an `_open` flag onto
/// the drawer control and this watches for it.
struct DrawerPresenter: ViewModifier {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .leading) { drawer(key: "drawer", edge: .leading) }
      .overlay(alignment: .trailing) { drawer(key: "end_drawer", edge: .trailing) }
      .animation(.easeOut(duration: 0.25), value: store.revision)
  }

  @ViewBuilder
  private func drawer(key: String, edge: Edge) -> some View {
    if let drawerID = node.controlID(forKey: key),
      let drawer = store.node(drawerID),
      drawer.bool("_open") == true
    {
      GeometryReader { proxy in
        ZStack(alignment: edge == .leading ? .leading : .trailing) {
          Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture { close(drawer) }
          ControlView(id: drawerID, axis: .vertical)
            // Flutter Material 3's NavigationDrawer default width is 360,
            // constrained by the available viewport on compact devices.
            .frame(width: min(proxy.size.width, 360))
            .transition(.move(edge: edge))
        }
      }
    }
  }

  private func close(_ drawer: ControlNode) {
    events.setLocal(drawer.id, "_open", .bool(false))
    events.fire(drawer, "dismiss")
  }
}

/// `PopupMenuButton` — an anchor that opens a menu of `PopupMenuItem`s.
struct PopupMenuControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var presented = false
  @State private var completedSelection = false

  var body: some View {
    Button {
      completedSelection = false
      presented = true
      events.fire(node, "open")
    } label: {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else if let content = node.string("content") {
        Text(content)
      } else if node.props["icon"] == nil {
        // Flutter's PopupMenuButton falls back to Icons.moreVert when neither
        // an icon nor child was supplied. Use the native semantic equivalent.
        Image(systemName: "ellipsis")
          .font(.system(size: iconSize))
          .foregroundColor(MaterialPalette.color(node.string("icon_color")))
          .frame(width: splashSide ?? 40, height: splashSide ?? 40)
          .contentShape(Rectangle())
      } else if let iconID = node.controlID(forKey: "icon") {
        ControlView(id: iconID, axis: .none)
          .frame(width: splashSide ?? 40, height: splashSide ?? 40)
          .contentShape(Rectangle())
      } else {
        RufletIcon(
          value: node.props["icon"], size: iconSize,
          color: MaterialPalette.color(node.string("icon_color")))
          .frame(width: splashSide ?? 40, height: splashSide ?? 40)
          .contentShape(Rectangle())
      }
    }
    .padding(MaterialMenuDefaults.popupPadding(node))
    .modifier(MaterialMenuButtonStyle(value: node.props["style"]))
    .modifier(ChromeClipModifier(behavior: MaterialMenuDefaults.popupClipBehavior(node)))
    .buttonStyle(.plain)
    .disabled(node.bool("disabled") ?? false)
    .modifier(TapFeedback(enabled: node.bool("enable_feedback") != false))
    .popover(isPresented: $presented, attachmentAnchor: menuAnchor) {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(itemIDs, id: \.self) { itemID in
          if let item = store.node(itemID), item.type == "PopupMenuItem" { menuItem(item) }
        }
      }
      .padding(ControlProps.edgeInsets(node.props["menu_padding"])
        ?? EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
      .frame(minWidth: 180)
      // PopupMenuButton.constraints constrains the popup route, not the
      // anchor button which opens it.
      .modifier(SlotSizeConstraints(value: node.props["size_constraints"]))
      .background(
        RoundedRectangle(cornerRadius: menuRadius)
          .fill(MaterialPalette.color(node.string("bgcolor"), default: .clear)))
      .shadow(
        color: MaterialPalette.color(
          node.string("shadow_color"), default: .black.opacity(0.2)),
        radius: CGFloat(node.double("elevation") ?? 8))
      .transition(.opacity)
      .animation(rufletAnimation(node.props["popup_animation_style"]), value: presented)
    }
    .onChange(of: presented) { open in
      if !open, !completedSelection { events.fire(node, "cancel") }
    }
  }

  /// `menu_position` is Flutter's `PopupMenuPosition`: the menu hangs under
  /// the button or covers it.
  private var menuAnchor: PopoverAttachmentAnchor {
    node.string("menu_position")?.lowercased() == "over"
      ? .rect(.bounds) : .rect(.bounds)
  }

  private var menuRadius: CGFloat {
    ControlProps.cornerRadius(node.map("shape")?["radius"]) ?? 8
  }

  /// `splash_radius` sizes the circle the button's press wash fills.
  private var splashSide: CGFloat? {
    node.double("splash_radius").map { CGFloat($0) * 2 }
  }

  private var iconSize: CGFloat {
    MaterialMenuDefaults.popupIconSize(node)
  }

  private var itemIDs: [Int] {
    MaterialMenuDefaults.controlIDs(node, key: "items")
  }

  @ViewBuilder
  private func menuItem(_ item: ControlNode) -> some View {
    let hasContent = item.controlID(forKey: "content") != nil
      || item.string("content") != nil || item.string("text") != nil
    let hasIcon = item.props["icon"] != nil
    if !hasContent && !hasIcon {
      Divider()
    } else {
      Button {
        completedSelection = true
        // Flet's popup entry value is the wire id of the selected item.
        events.fire(node, "select", data: .string(String(item.id)))
        if let checked = item.bool("checked") {
          events.fire(item, "click", data: .bool(!checked))
        } else {
          events.fire(item, "click")
        }
        presented = false
      } label: {
        HStack {
          if let checked = item.bool("checked") {
            Group {
              if checked {
                Image(systemName: "checkmark")
              } else {
                Color.clear.frame(width: 18, height: 1)
              }
            }
            .frame(width: 18)
          }
          if let iconID = item.controlID(forKey: "icon") {
            ControlView(id: iconID, axis: .none)
          } else if item.props["icon"] != nil {
            RufletIcon(value: item.props["icon"], size: 16, color: nil)
          }
          if let contentID = item.controlID(forKey: "content") {
            ControlView(id: contentID, axis: .none)
          } else {
            Text(item.string("content") ?? item.string("text") ?? "")
          }
        }
        .padding(ControlProps.edgeInsets(item.props["padding"]) ?? EdgeInsets())
        .frame(minHeight: MaterialMenuDefaults.popupItemHeight(item))
        .rufletTextStyle(RufletTextStyle(node: item, styleKey: "label_text_style"))
      }
      .disabled(item.bool("disabled") ?? false)
    }
  }
}

/// `MenuBar` — a row of `SubmenuButton`s.
struct MenuBarControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore

  @ViewBuilder
  var body: some View {
    if visibleControlIDs.isEmpty {
      // Flet renders ErrorControl here rather than silently accepting an
      // empty MenuBar. Keep the same failure visible to app developers.
      Text("MenuBar must have at minimum one visible child control")
        .foregroundColor(.red)
    } else {
      HStack(spacing: 4) {
        ControlList(ids: visibleControlIDs, axis: .horizontal)
      }
      .modifier(MenuSurfaceStyle(value: node.props["style"]))
      .modifier(ChromeClipModifier(behavior: MaterialMenuDefaults.menuBarClipBehavior(node)))
    }
  }

  private var visibleControlIDs: [Int] {
    MaterialMenuDefaults.visibleControlIDs(node, key: "controls") {
      store.node($0)?.bool("visible")
    }
  }
}

/// `SubmenuButton` — a labelled menu that can nest further submenus.
struct SubmenuButtonControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var presented = false
  @FocusState private var focused: Bool

  /// `alignment_offset` shifts the submenu from where it would otherwise
  /// hang off its parent.
  private var submenuOffset: CGSize {
    guard let map = node.map("alignment_offset") else { return .zero }
    return CGSize(
      width: CGFloat(map["x"]?.doubleValue ?? 0),
      height: CGFloat(map["y"]?.doubleValue ?? 0))
  }

  var body: some View {
    Button {
      presented.toggle()
    } label: {
      HStack(spacing: 8) {
        if let leadingID = node.controlID(forKey: "leading") {
          ControlView(id: leadingID, axis: .none)
        }
        if let contentID = node.controlID(forKey: "content") {
          ControlView(id: contentID, axis: .none)
        } else {
          Text(node.string("content") ?? node.string("text") ?? "")
        }
        if let trailingID = node.controlID(forKey: "trailing") {
          ControlView(id: trailingID, axis: .none)
        }
      }
    }
    .buttonStyle(.plain)
    .modifier(MaterialMenuButtonStyle(value: node.props["style"], appliesConstructorDefaults: true))
    .modifier(ChromeClipModifier(behavior: MaterialMenuDefaults.submenuClipBehavior(node)))
    .disabled(node.bool("disabled") ?? false)
    .focused($focused)
    .popover(
      isPresented: $presented,
      attachmentAnchor: .rect(.bounds)
    ) {
      ControlList(ids: controlIDs, axis: .vertical)
        .padding(.vertical, 6)
        .frame(minWidth: 180)
        // Flutter applies alignment_offset and menu_style to the submenu
        // surface, not to the button which opened it.
        .offset(submenuOffset)
        .modifier(MenuSurfaceStyle(value: node.props["menu_style"]))
    }
    .onChange(of: presented) { open in
      guard node.bool("disabled") != true else { return }
      if open, MaterialMenuDefaults.shouldEmit(node, event: "open") {
        events.fire(node, "open")
      }
      if !open, MaterialMenuDefaults.shouldEmit(node, event: "close") {
        events.fire(node, "close")
      }
    }
    .onHover { inside in
      if MaterialMenuDefaults.shouldEmit(node, event: "hover") {
        events.fire(node, "hover", data: .bool(inside))
      }
    }
    .onChange(of: focused) { isFocused in
      events.fire(node, isFocused ? "focus" : "blur")
    }
    .onAppear {
      if node.string("focus") != nil { focused = true }
    }
    .onChange(of: node.string("focus")) { value in
      if value != nil { focused = true }
    }
  }

  private var controlIDs: [Int] {
    MaterialMenuDefaults.controlIDs(node, key: "controls")
  }
}

/// `MenuItemButton` — one row of a menu.
struct MenuItemButtonControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @Environment(\.dismiss) private var dismiss
  @FocusState private var focused: Bool

  /// `overflow_axis` is the direction a menu item's content runs when it does
  /// not fit on one line.
  @ViewBuilder
  private func menuItemStack<Content: View>(
    spacing: CGFloat, @ViewBuilder content: () -> Content
  ) -> some View {
    if node.string("overflow_axis")?.lowercased() == "vertical" {
      VStack(alignment: .leading, spacing: spacing) { content() }
    } else {
      HStack(spacing: spacing) { content() }
    }
  }

  var body: some View {
    Button {
      if MaterialMenuDefaults.shouldEmit(node, event: "click") { events.fire(node, "click") }
      if MaterialMenuDefaults.menuItemClosesOnClick(node) { dismiss() }
    } label: {
      // `overflow_axis` is the direction the item's content runs when it does
      // not fit; Flutter lays a menu item out along it.
      menuItemStack(spacing: 8) {
        if let leadingID = node.controlID(forKey: "leading") {
          ControlView(id: leadingID, axis: .none)
        }
        if let contentID = node.controlID(forKey: "content") {
          ControlView(id: contentID, axis: .none)
        } else {
          Text(node.string("content") ?? node.string("text") ?? "")
        }
        if let trailingID = node.controlID(forKey: "trailing_icon")
          ?? node.controlID(forKey: "trailing") {
          ControlView(id: trailingID, axis: .none)
        }
      }
    }
    .buttonStyle(.plain)
    .modifier(MaterialMenuButtonStyle(value: node.props["style"], appliesConstructorDefaults: true))
    .modifier(ChromeClipModifier(behavior: MaterialMenuDefaults.menuItemClipBehavior(node)))
    // Flutter receives a nil `onPressed` when no click handler is attached,
    // which makes the MenuItemButton disabled even if `disabled` is false.
    .disabled(!MaterialMenuDefaults.shouldEmit(node, event: "click"))
    .focused($focused)
    .modifier(MenuSemanticLabel(value: node.string("semantics_label") ?? node.string("semantic_label")))
    .onAppear {
      if node.bool("autofocus") == true || node.string("focus") != nil { focused = true }
    }
    .onChange(of: node.string("focus")) { value in
      if value != nil { focused = true }
    }
    .onHover { inside in
      if inside, MaterialMenuDefaults.menuItemFocusesOnHover(node) { focused = true }
      if MaterialMenuDefaults.shouldEmit(node, event: "hover") {
        events.fire(node, "hover", data: .bool(inside))
      }
    }
    .onChange(of: focused) { isFocused in
      events.fire(node, isFocused ? "focus" : "blur")
    }
  }
}

/// Constructor values from Flet 0.80.5's Material menu controls. Keeping the
/// omission rules here prevents each SwiftUI view from inventing a different
/// fallback and gives parity tests a stable, source-derived seam.
enum MaterialMenuDefaults {
  static func popupIconSize(_ node: ControlNode) -> CGFloat {
    CGFloat(node.double("icon_size") ?? 24)
  }

  static func popupPadding(_ node: ControlNode) -> EdgeInsets {
    ControlProps.edgeInsets(node.props["padding"])
      ?? EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
  }

  static func popupClipBehavior(_ node: ControlNode) -> String {
    node.string("clip_behavior") ?? "none"
  }

  static func popupItemHeight(_ node: ControlNode) -> CGFloat {
    CGFloat(node.double("height") ?? 48)
  }

  static func menuBarClipBehavior(_ node: ControlNode) -> String {
    node.string("clip_behavior") ?? "none"
  }

  static func submenuClipBehavior(_ node: ControlNode) -> String {
    node.string("clip_behavior") ?? "hardEdge"
  }

  static func menuItemClipBehavior(_ node: ControlNode) -> String {
    node.string("clip_behavior") ?? "none"
  }

  static func menuItemClosesOnClick(_ node: ControlNode) -> Bool {
    node.bool("close_on_click") ?? true
  }

  static func menuItemFocusesOnHover(_ node: ControlNode) -> Bool {
    node.bool("focus_on_hover") ?? true
  }

  static func shouldEmit(_ node: ControlNode, event: String) -> Bool {
    node.bool("disabled") != true && node.bool("on_\(event)") == true
  }

  static func controlIDs(_ node: ControlNode, key: String) -> [Int] {
    // `control.children(key)` reads exactly the named Flet slot. Pulling the
    // generic `controls` collection into an `items` slot can silently render
    // unrelated controls in a popup.
    orderedUnique(node.controlIDs(forKey: key))
  }

  static func visibleControlIDs(
    _ node: ControlNode,
    key: String,
    visibilityForID: (Int) -> Bool?
  ) -> [Int] {
    controlIDs(node, key: key).filter { visibilityForID($0) != false }
  }
}

/// Source-derived behavior shared by every native `ContextMenu` presentation.
///
/// Flet distinguishes an explicit pointer button from a programmatic `open`:
/// button gestures read that button's item collection, while `open` passes no
/// button and reads the common `items` collection. This type deliberately
/// keeps the distinction instead of collapsing both paths into "primary".
enum RufletContextMenuDefaults {
  struct PointerAction: Equatable {
    let button: String
    let gesture: String
  }

  static func trigger(_ node: ControlNode, button: String?) -> String? {
    guard let button else { return nil }
    let explicit: String?
    let fallback: String
    switch button.lowercased() {
    case "secondary":
      explicit = node.string("secondary_trigger")
      fallback = "down"
    case "tertiary":
      explicit = node.string("tertiary_trigger")
      fallback = "down"
    default:
      explicit = node.string("primary_trigger")
      fallback = "disabled"
    }
    return normalizedTrigger(explicit ?? fallback)
  }

  static func itemIDs(_ node: ControlNode, button: String?) -> [Int] {
    guard let button else {
      return orderedUnique(node.controlIDs(forKey: "items"))
    }
    switch button.lowercased() {
    case "secondary": return orderedUnique(node.controlIDs(forKey: "secondary_items"))
    case "tertiary": return orderedUnique(node.controlIDs(forKey: "tertiary_items"))
    default: return orderedUnique(node.controlIDs(forKey: "primary_items"))
    }
  }

  static func popupItemIDs(
    _ node: ControlNode,
    button: String?,
    typeForID: (Int) -> String?
  ) -> [Int] {
    itemIDs(node, button: button).filter { typeForID($0) == "PopupMenuItem" }
  }

  static func permitsGesture(_ node: ControlNode, button: String, gesture: String) -> Bool {
    trigger(node, button: button) == normalizedTrigger(gesture)
  }

  /// Maps the native monitor's source events back to the two Flet trigger
  /// modes. Tap-down is intentionally used instead of tap-up: Dart opens the
  /// menu from Listener.onPointerDown.
  static func pointerAction(_ node: ControlNode, nativeEvent: String) -> PointerAction? {
    let candidate: PointerAction?
    switch nativeEvent {
    case "secondary_tap_down":
      candidate = PointerAction(button: "secondary", gesture: "down")
    case "tertiary_tap_down":
      candidate = PointerAction(button: "tertiary", gesture: "down")
    case "secondary_long_press_start":
      candidate = PointerAction(button: "secondary", gesture: "longPress")
    case "tertiary_long_press_start":
      candidate = PointerAction(button: "tertiary", gesture: "longPress")
    default:
      candidate = nil
    }
    guard let candidate,
      permitsGesture(node, button: candidate.button, gesture: candidate.gesture)
    else { return nil }
    return candidate
  }

  static func point(_ value: RufletValue?) -> CGPoint? {
    guard let map = value?.mapValue,
          let x = map["x"]?.doubleValue,
          let y = map["y"]?.doubleValue else { return nil }
    return CGPoint(x: x, y: y)
  }

  /// Mirrors Flet's local/global conversion and center fallback for `open`.
  static func positions(
    global: CGPoint?, local: CGPoint?, frame: CGRect
  ) -> (global: CGPoint, local: CGPoint) {
    if let local, global == nil {
      return (CGPoint(x: frame.minX + local.x, y: frame.minY + local.y), local)
    }
    if let global, local == nil {
      return (global, CGPoint(x: global.x - frame.minX, y: global.y - frame.minY))
    }
    if let global, let local { return (global, local) }
    let localCenter = CGPoint(x: frame.width / 2, y: frame.height / 2)
    return (
      CGPoint(x: frame.minX + localCenter.x, y: frame.minY + localCenter.y),
      localCenter)
  }

  static func eventPayload(
    node: ControlNode,
    button: String?,
    global: CGPoint,
    local: CGPoint?,
    itemID: Int? = nil,
    itemIndex: Int? = nil,
    itemCount: Int
  ) -> [String: RufletValue] {
    [
      "b": button.map(RufletValue.string) ?? .null,
      "tr": trigger(node, button: button).map(RufletValue.string) ?? .null,
      "id": itemID.map { .int(Int64($0)) } ?? .null,
      "idx": itemIndex.map { .int(Int64($0)) } ?? .null,
      "ic": .int(Int64(itemCount)),
      "g": .map(["x": .double(Double(global.x)), "y": .double(Double(global.y))]),
      "l": local.map {
        .map(["x": .double(Double($0.x)), "y": .double(Double($0.y))])
      } ?? .null,
    ]
  }

  private static func normalizedTrigger(_ value: String) -> String {
    let compact = value.replacingOccurrences(of: "_", with: "")
      .replacingOccurrences(of: "-", with: "")
      .lowercased()
    return compact == "longpress" ? "longPress" : compact
  }
}

/// Menu buttons use the same Flet ButtonStyle map as Material buttons, with
/// the constructor defaults supplied by SubmenuButton/MenuItemButton.
private struct MaterialMenuButtonStyle: ViewModifier {
  let value: RufletValue?
  var appliesConstructorDefaults = false

  func body(content: Content) -> some View {
    guard appliesConstructorDefaults || value?.mapValue != nil else { return AnyView(content) }
    let style = value?.mapValue ?? [:]
    let radius = ControlProps.cornerRadius(style["shape"]?.mapValue?["radius"]) ?? 999
    let padding = ControlProps.edgeInsets(style["padding"])
      ?? EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    let elevation = CGFloat(style["elevation"]?.doubleValue ?? 0)
    return AnyView(
      content
        .padding(padding)
        .foregroundColor(MaterialPalette.color(
          style["color"]?.stringValue,
          default: MaterialPalette.color("primary", default: .accentColor)))
        .background(
          RoundedRectangle(cornerRadius: radius)
            .fill(MaterialPalette.color(style["bgcolor"]?.stringValue, default: .clear)))
        .shadow(
          color: MaterialPalette.color(
            style["shadow_color"]?.stringValue, default: .clear),
          radius: elevation, y: elevation / 2))
  }
}

private struct MenuSemanticLabel: ViewModifier {
  let value: String?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let value { content.accessibilityLabel(value) } else { content }
  }
}

private func orderedUnique(_ ids: [Int]) -> [Int] {
  var seen = Set<Int>()
  return ids.filter { seen.insert($0).inserted }
}

/// `ContextMenu` — a right-click / long-press menu around its content.
struct ContextMenuControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var presented = false
  @State private var completedSelection = false
  @State private var activeButton: String?
  @State private var activeGlobalPosition = CGPoint.zero
  @State private var activeLocalPosition: CGPoint?
  @State private var contentFrame = CGRect.zero
  @State private var primaryPressGlobalPosition: CGPoint?

  var body: some View {
    Group {
      if node.type == "CupertinoContextMenu" {
        CupertinoContextMenuControlView(node: node)
      } else if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        Text("ContextMenu.content must be visible")
          .foregroundColor(.red)
      }
    }
    .contentShape(Rectangle())
    .simultaneousGesture(
      DragGesture(minimumDistance: 0, coordinateSpace: .global)
        .onChanged { primaryPressGlobalPosition = $0.location }
        .onEnded { primaryPressGlobalPosition = $0.location })
    .onLongPressGesture {
      guard node.type != "CupertinoContextMenu" else { return }
      guard RufletContextMenuDefaults.permitsGesture(
        node, button: "primary", gesture: "long_press") else { return }
      let global = primaryPressGlobalPosition
      let local = global.map {
        CGPoint(x: $0.x - contentFrame.minX, y: $0.y - contentFrame.minY)
      }
      open(button: "primary", global: global, local: local)
    }
    .modifier(ContextMenuPointerTriggers(node: node) { button, local in
      open(button: button, global: nil, local: local)
    })
    .background(
      GeometryReader { proxy in
        Color.clear.preference(
          key: ContextMenuFramePreference.self,
          value: proxy.frame(in: .global))
      })
    .onPreferenceChange(ContextMenuFramePreference.self) { contentFrame = $0 }
    .popover(isPresented: $presented, attachmentAnchor: popoverAnchor) {
      VStack(alignment: .leading, spacing: 0) {
        popoverMenuItems(button: activeButton)
      }
      .padding(.vertical, 6)
      .frame(minWidth: 180)
    }
    .onChange(of: presented) { open in
      if !open, !completedSelection {
        events.fire(node, "dismiss", data: .map(eventPayload(button: activeButton)))
      }
    }
    .rufletCommandHandler(node.id) { call, completion in
      guard node.type != "CupertinoContextMenu" else {
        completion(.failure(rufletUnsupported(node.type, call)))
        return
      }
      guard call.name == "open" else {
        completion(.failure(rufletUnsupported(node.type, call)))
        return
      }
      let positions = RufletContextMenuDefaults.positions(
        global: RufletContextMenuDefaults.point(call.argument("global_position")),
        local: RufletContextMenuDefaults.point(call.argument("local_position")),
        frame: contentFrame)
      open(button: nil, global: positions.global, local: positions.local)
      completion(.success(.null))
    }
  }

  private var popoverAnchor: PopoverAttachmentAnchor {
    guard let local = activeLocalPosition,
          contentFrame.width > 0, contentFrame.height > 0 else { return .rect(.bounds) }
    return .point(UnitPoint(
      x: min(max(local.x / contentFrame.width, 0), 1),
      y: min(max(local.y / contentFrame.height, 0), 1)))
  }

  private func open(button: String?, global: CGPoint?, local: CGPoint?) {
    let positions = RufletContextMenuDefaults.positions(
      global: global, local: local, frame: contentFrame)
    activeButton = button
    activeGlobalPosition = positions.global
    activeLocalPosition = positions.local
    completedSelection = false
    if itemIDs(button: button).isEmpty {
      events.fire(node, "dismiss", data: .map(eventPayload(button: button)))
      return
    }
    presented = true
  }

  private func itemIDs(button: String?) -> [Int] {
    RufletContextMenuDefaults.popupItemIDs(node, button: button) {
      store.node($0)?.type
    }
  }

  @ViewBuilder
  private func popoverMenuItems(button: String?) -> some View {
    ForEach(itemIDs(button: button), id: \.self) { itemID in
      if let item = store.node(itemID) { contextItem(item, button: button) }
    }
  }

  @ViewBuilder
  private func contextItem(_ item: ControlNode, button: String?) -> some View {
    let hasContent = item.controlID(forKey: "content") != nil
      || item.string("content") != nil || item.string("text") != nil
    let hasIcon = item.props["icon"] != nil
    if !hasContent && !hasIcon {
      Divider()
    } else {
      Button {
        select(item, button: button)
      } label: {
        HStack(spacing: 8) {
          if let iconID = item.controlID(forKey: "icon") {
            ControlView(id: iconID, axis: .none)
          } else if item.props["icon"] != nil {
            RufletIcon(value: item.props["icon"], size: 16, color: nil)
          }
          if let contentID = item.controlID(forKey: "content") {
            ControlView(id: contentID, axis: .none)
          } else {
            Text(item.string("content") ?? item.string("text") ?? "")
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
      }
      .buttonStyle(.plain)
      .disabled(item.bool("disabled") ?? false)
    }
  }

  private func select(_ item: ControlNode, button: String?) {
    completedSelection = true
    let ids = itemIDs(button: button)
    var payload = eventPayload(button: button)
    payload["id"] = .int(Int64(item.id))
    payload["idx"] = .int(Int64(ids.firstIndex(of: item.id) ?? 0))
    // PopupMenuItem.onTap runs before showMenu's Future completes and the
    // parent receives `select`, so preserve that observable event order.
    if let checked = item.bool("checked") {
      events.fire(item, "click", data: .bool(!checked))
    } else {
      events.fire(item, "click")
    }
    events.fire(node, "select", data: .map(payload))
    presented = false
  }

  private func eventPayload(button: String?) -> [String: RufletValue] {
    let ids = itemIDs(button: button)
    return RufletContextMenuDefaults.eventPayload(
      node: node,
      button: button,
      global: activeGlobalPosition,
      local: activeLocalPosition,
      itemCount: ids.count)
  }
}

private struct ContextMenuFramePreference: PreferenceKey {
  static var defaultValue: CGRect = .zero
  static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

/// Bridges the pointer channels used by Flet's ContextMenu GestureDetector.
/// SwiftUI's `contextMenu` does not expose tertiary buttons, trigger timing,
/// positions, or dismissal, while the existing native monitor does.
private struct ContextMenuPointerTriggers: ViewModifier {
  let node: ControlNode
  let open: (String, CGPoint) -> Void

  func body(content: Content) -> some View {
    guard node.type != "CupertinoContextMenu" else { return AnyView(content) }
    #if os(macOS)
      return AnyView(content.overlay(
        RufletNativePointerMonitor { name, payload in
          guard let action = RufletContextMenuDefaults.pointerAction(
            node, nativeEvent: name),
            let localValue = payload.mapValue?["l"],
            let local = RufletContextMenuDefaults.point(localValue)
          else { return }
          open(action.button, local)
        }
        .allowsHitTesting(false)))
    #else
      return AnyView(content)
    #endif
  }
}
