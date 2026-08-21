import RufletProtocol
import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

/// Apple-native port of pinned `alert_dialog.dart`.
@MainActor
public struct AlertDialogControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    RufletAppleDialogPresenter(control: control)
  }
}

@MainActor
struct RufletAppleDialogPresenter: View {
  @ObservedObject var control: RufletControl
  @State private var presented = false

  var body: some View {
    ZStack {
      RufletPresentationLifecycleAnchor()
      if let validationError {
        rendererError(validationError)
      } else {
        switch nativeAlertResolution {
        case .native(let descriptor):
          RufletNativeAlertAnchor(
            presented: presented,
            descriptor: descriptor,
            onAction: performNativeAction
          )
          .frame(width: 0, height: 0)
          .accessibilityHidden(true)
        case .protocolError(let reason):
          if control.boolean("open", default: false) || presented {
            rendererError(reason)
          }
        }
      }
    }
    .onAppear(perform: synchronizePresentation)
    .onChange(of: control.revision) { _ in synchronizePresentation() }
  }

  private func rendererError(_ reason: String) -> some View {
    ErrorControl(
      "Native renderer protocol error",
      description: "\(control.type)#\(control.id): \(reason)")
  }

  private func synchronizePresentation() {
    let open = control.boolean("open", default: false)
    let lastOpen = control.boolean("_open", default: false)
    guard case .native = nativeAlertResolution else {
      if presented { close(reportDismiss: false) }
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
      withAnimation(dialogAnimation) { presented = true }
    } else if !open, lastOpen, presented {
      close()
    }
  }

  private func close(reportDismiss: Bool = true) {
    withAnimation(dialogAnimation) { presented = false }
    control.updateProperties(["_open": .bool(false)], server: false)
    control.updateProperties(["open": .bool(false)])
    if reportDismiss { control.triggerEvent("dismiss") }
  }

  private func performNativeAction(_ action: RufletNativeAlertAction) {
    if action.subscribed {
      control.backend.triggerControlEvent(
        controlID: action.id,
        name: "click",
        data: .null)
    }
    close()
  }

  private var nativeAlertResolution: RufletNativeAlertResolution {
    rufletNativeAlertResolution(for: control)
  }

  private var hasContent: Bool {
    control.value("title").map { !$0.isNull } ?? false
      || control.value("content").map { !$0.isNull } ?? false
      || !control.children("actions").isEmpty
  }
  private var modalKind: RufletModalKind {
    control.type == "AlertDialog" ? .alertDialog : .cupertinoAlertDialog
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
}

struct RufletNativeAlertAction: Equatable {
  enum Role: Equatable {
    case `default`
    case destructive
  }

  let id: Int
  let title: String
  let role: Role
  let enabled: Bool
  let preferred: Bool
  let subscribed: Bool
}

struct RufletNativeAlertDescriptor: Equatable {
  let title: String?
  let message: String?
  let actions: [RufletNativeAlertAction]
  let semanticsLabel: String?
}

enum RufletNativeAlertResolution: Equatable {
  case native(RufletNativeAlertDescriptor)
  case protocolError(String)
}

private struct RufletNativeAlertProtocolError: LocalizedError {
  let reason: String
  var errorDescription: String? { reason }
}

/// Builds only descriptions which UIKit can represent without private API.
/// Rails and other protocol producers may place a message and its buttons in
/// one layout control instead of splitting them into `content` and `actions`.
/// Transparently walking that wire structure keeps the renderer generic while
/// still letting `UIAlertController` own all alert chrome and motion.
@MainActor
func rufletNativeAlertResolution(for control: RufletControl) -> RufletNativeAlertResolution {
  do {
    return .native(try rufletBuildNativeAlertDescriptor(for: control))
  } catch let error as RufletNativeAlertProtocolError {
    return .protocolError(error.reason)
  } catch {
    return .protocolError(error.localizedDescription)
  }
}

@MainActor
func rufletNativeAlertDescriptor(for control: RufletControl) -> RufletNativeAlertDescriptor? {
  guard case .native(let descriptor) = rufletNativeAlertResolution(for: control) else {
    return nil
  }
  return descriptor
}

@MainActor
private func rufletBuildNativeAlertDescriptor(
  for control: RufletControl
) throws -> RufletNativeAlertDescriptor {
  if control.child("icon") != nil || control.integer("icon") != nil {
    throw RufletNativeAlertProtocolError(
      reason: "icon cannot be represented by the public Apple alert API")
  }
  if let property = rufletUnsupportedNativeAlertStylingProperty(control) {
    throw RufletNativeAlertProtocolError(
      reason: "\(property) cannot be applied by the public Apple alert API")
  }

  let title = rufletNativePlainText("title", of: control)
  if rufletHasNonNullValue("title", of: control), title == nil {
    throw RufletNativeAlertProtocolError(
      reason: "title must be a string, Text, or SelectableText for a native Apple alert")
  }

  var message: String?
  var embeddedActions: [RufletNativeAlertAction] = []
  if let content = control.child("content") {
    let parts = try rufletNativeAlertContent(content)
    let text = parts.messages.filter { !$0.isEmpty }.joined(separator: "\n\n")
    message = text.isEmpty ? nil : text
    embeddedActions = parts.actions
  } else if let text = control.string("content") {
    message = text
  } else if rufletHasNonNullValue("content", of: control) {
    throw RufletNativeAlertProtocolError(
      reason: "content must be native alert text, actions, or transparent layout wrappers")
  }

  let declaredActions = try control.children("actions").map(rufletNativeAlertAction)
  let actions = embeddedActions + declaredActions
  guard title != nil || message != nil || !actions.isEmpty else {
    let kind: RufletModalKind =
      control.type == "AlertDialog" ? .alertDialog : .cupertinoAlertDialog
    throw RufletNativeAlertProtocolError(reason: kind.missingContentMessage)
  }
  return RufletNativeAlertDescriptor(
    title: title,
    message: message,
    actions: actions,
    semanticsLabel: control.string("semantics_label"))
}

private struct RufletNativeAlertContent {
  var messages: [String] = []
  var actions: [RufletNativeAlertAction] = []
}

@MainActor
private func rufletNativeAlertContent(_ source: RufletControl) throws -> RufletNativeAlertContent {
  let source = source.unwrapComponent()
  if let text = rufletNativePlainText(source) {
    return RufletNativeAlertContent(messages: [text])
  }
  if rufletNativeAlertButtonTypes.contains(source.type) {
    return RufletNativeAlertContent(actions: [try rufletNativeAlertAction(source)])
  }

  let children: [RufletControl]
  switch source.type {
  case "Column", "Row", "Stack", "ResponsiveRow", "ListView", "GridView":
    children = source.children("controls")
  case "Container", "Center", "SafeArea", "TransparentPointer", "IgnorePointer":
    guard let content = source.child("content") else {
      throw RufletNativeAlertProtocolError(
        reason: "\(source.type)#\(source.id) has no visible content")
    }
    children = [content]
  default:
    throw RufletNativeAlertProtocolError(
      reason: "\(source.type)#\(source.id) is not representable by the public Apple alert API")
  }
  guard !children.isEmpty else {
    throw RufletNativeAlertProtocolError(
      reason: "\(source.type)#\(source.id) has no visible alert content")
  }

  var result = RufletNativeAlertContent()
  for child in children {
    let part = try rufletNativeAlertContent(child)
    result.messages.append(contentsOf: part.messages)
    result.actions.append(contentsOf: part.actions)
  }
  return result
}

private let rufletNativeAlertButtonTypes: Set<String> = [
  "AdaptiveButton", "Button", "CupertinoButton", "CupertinoDialogAction",
  "CupertinoFilledButton", "CupertinoTintedButton", "FilledButton",
  "FilledTonalButton", "OutlinedButton", "TextButton",
]

@MainActor
private func rufletNativeAlertAction(_ action: RufletControl) throws -> RufletNativeAlertAction {
  let action = action.unwrapComponent()
  guard rufletNativeAlertButtonTypes.contains(action.type) else {
    throw RufletNativeAlertProtocolError(
      reason: "\(action.type)#\(action.id) is not a native alert action")
  }
  guard let title = rufletNativePlainText("content", of: action), !title.isEmpty else {
    throw RufletNativeAlertProtocolError(
      reason: "\(action.type)#\(action.id) action content must resolve to non-empty text")
  }
  let role: RufletNativeAlertAction.Role =
    action.boolean("destructive", default: false) ? .destructive : .default
  return RufletNativeAlertAction(
    id: action.id,
    title: title,
    role: role,
    enabled: !action.disabled,
    preferred: action.boolean("default", default: false),
    subscribed: action.hasEventHandler("click"))
}

@MainActor
private func rufletHasNonNullValue(_ name: String, of control: RufletControl) -> Bool {
  guard let value = control.value(name) else { return false }
  return !value.isNull
}

@MainActor
private func rufletUnsupportedNativeAlertStylingProperty(_ control: RufletControl) -> String? {
  [
    "title_padding", "content_padding", "actions_padding", "actions_alignment",
    "shape", "inset_padding", "icon_padding", "bgcolor", "action_button_padding",
    "shadow_color", "elevation", "clip_behavior", "icon_color", "scrollable",
    "actions_overflow_button_spacing", "alignment", "content_text_style",
    "title_text_style", "barrier_color",
  ].first { rufletHasNonNullValue($0, of: control) }
}

#if os(iOS)
  /// An invisible SwiftUI bridge whose presented controller is the public
  /// UIKit alert. No alert chrome is drawn by Ruflet, so iOS remains free to
  /// update materials, spacing, typography and motion in future releases.
  @MainActor
  private struct RufletNativeAlertAnchor: UIViewControllerRepresentable {
    let presented: Bool
    let descriptor: RufletNativeAlertDescriptor
    let onAction: (RufletNativeAlertAction) -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(onAction: onAction)
    }

    func makeUIViewController(context: Context) -> UIViewController {
      let host = UIViewController()
      host.view.backgroundColor = .clear
      host.view.isUserInteractionEnabled = false
      return host
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
      context.coordinator.onAction = onAction
      context.coordinator.update(
        host: host,
        presented: presented,
        descriptor: descriptor)
    }

    static func dismantleUIViewController(_ host: UIViewController, coordinator: Coordinator) {
      coordinator.dismiss(from: host, animated: false)
    }

    @MainActor
    final class Coordinator: NSObject {
      var onAction: (RufletNativeAlertAction) -> Void
      private weak var alert: UIAlertController?
      private var descriptor: RufletNativeAlertDescriptor?
      private var wantsPresentation = false
      private var suppressUntilClosed = false

      init(onAction: @escaping (RufletNativeAlertAction) -> Void) {
        self.onAction = onAction
      }

      func update(
        host: UIViewController,
        presented: Bool,
        descriptor: RufletNativeAlertDescriptor
      ) {
        wantsPresentation = presented
        if !presented {
          suppressUntilClosed = false
          dismiss(from: host, animated: true)
          return
        }
        guard !suppressUntilClosed else { return }
        if self.descriptor == descriptor, alert != nil { return }
        if alert != nil {
          dismiss(from: host, animated: false) { [weak self, weak host] in
            guard let self, let host else { return }
            self.presentIfPossible(from: host, descriptor: descriptor)
          }
        } else {
          presentIfPossible(from: host, descriptor: descriptor)
        }
      }

      func dismiss(
        from host: UIViewController,
        animated: Bool,
        completion: (() -> Void)? = nil
      ) {
        descriptor = nil
        guard let alert else {
          completion?()
          return
        }
        self.alert = nil
        if alert.presentingViewController != nil {
          alert.dismiss(animated: animated, completion: completion)
        } else {
          host.dismiss(animated: animated, completion: completion)
        }
      }

      private func presentIfPossible(
        from host: UIViewController,
        descriptor: RufletNativeAlertDescriptor
      ) {
        guard wantsPresentation, !suppressUntilClosed, alert == nil else { return }
        guard host.viewIfLoaded?.window != nil else {
          DispatchQueue.main.async { [weak self, weak host] in
            guard let self, let host else { return }
            self.presentIfPossible(from: host, descriptor: descriptor)
          }
          return
        }

        let alert = UIAlertController(
          title: descriptor.title,
          message: descriptor.message,
          preferredStyle: .alert)
        alert.view.accessibilityLabel = descriptor.semanticsLabel
        for item in descriptor.actions {
          let nativeAction = UIAlertAction(
            title: item.title,
            style: item.role == .destructive ? .destructive : .default
          ) { [weak self] _ in
            guard let self else { return }
            self.alert = nil
            self.descriptor = nil
            self.suppressUntilClosed = true
            self.onAction(item)
          }
          nativeAction.isEnabled = item.enabled
          alert.addAction(nativeAction)
          if item.preferred { alert.preferredAction = nativeAction }
        }
        self.descriptor = descriptor
        self.alert = alert
        host.present(alert, animated: true)
      }
    }
  }
#elseif os(macOS)
  /// An invisible SwiftUI bridge to AppKit's public `NSAlert` sheet API.
  @MainActor
  private struct RufletNativeAlertAnchor: NSViewControllerRepresentable {
    let presented: Bool
    let descriptor: RufletNativeAlertDescriptor
    let onAction: (RufletNativeAlertAction) -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(onAction: onAction)
    }

    func makeNSViewController(context: Context) -> NSViewController {
      NSViewController()
    }

    func updateNSViewController(_ host: NSViewController, context: Context) {
      context.coordinator.onAction = onAction
      context.coordinator.update(
        host: host,
        presented: presented,
        descriptor: descriptor)
    }

    static func dismantleNSViewController(_ host: NSViewController, coordinator: Coordinator) {
      coordinator.dismiss(animated: false)
    }

    @MainActor
    final class Coordinator: NSObject {
      var onAction: (RufletNativeAlertAction) -> Void
      private var alert: NSAlert?
      private var descriptor: RufletNativeAlertDescriptor?
      private var wantsPresentation = false
      private var suppressUntilClosed = false

      init(onAction: @escaping (RufletNativeAlertAction) -> Void) {
        self.onAction = onAction
      }

      func update(
        host: NSViewController,
        presented: Bool,
        descriptor: RufletNativeAlertDescriptor
      ) {
        wantsPresentation = presented
        if !presented {
          suppressUntilClosed = false
          dismiss(animated: true)
          return
        }
        guard !suppressUntilClosed else { return }
        if self.descriptor == descriptor, alert != nil { return }
        dismiss(animated: false)
        presentIfPossible(from: host, descriptor: descriptor)
      }

      func dismiss(animated: Bool) {
        _ = animated
        descriptor = nil
        guard let alert else { return }
        self.alert = nil
        let window = alert.window
        if let parent = window.sheetParent {
          parent.endSheet(window)
        }
        window.orderOut(nil)
      }

      private func presentIfPossible(
        from host: NSViewController,
        descriptor: RufletNativeAlertDescriptor
      ) {
        guard wantsPresentation, !suppressUntilClosed, alert == nil else { return }
        guard let window = host.view.window else {
          DispatchQueue.main.async { [weak self, weak host] in
            guard let self, let host else { return }
            self.presentIfPossible(from: host, descriptor: descriptor)
          }
          return
        }

        let alert = NSAlert()
        if let title = descriptor.title {
          alert.messageText = title
          alert.informativeText = descriptor.message ?? ""
        } else {
          alert.messageText = descriptor.message ?? ""
        }
        alert.alertStyle = .informational
        for item in descriptor.actions {
          let button = alert.addButton(withTitle: item.title)
          button.isEnabled = item.enabled
          if #available(macOS 11.0, *), item.role == .destructive {
            button.hasDestructiveAction = true
          }
          if item.preferred { button.keyEquivalent = "\r" }
        }
        if let semanticsLabel = descriptor.semanticsLabel {
          alert.window.setAccessibilityLabel(semanticsLabel)
        }
        self.descriptor = descriptor
        self.alert = alert
        alert.beginSheetModal(for: window) { [weak self] response in
          guard let self else { return }
          self.alert = nil
          self.descriptor = nil
          let first = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
          let index = response.rawValue - first
          guard descriptor.actions.indices.contains(index) else { return }
          self.suppressUntilClosed = true
          self.onAction(descriptor.actions[index])
        }
      }
    }
  }
#endif
