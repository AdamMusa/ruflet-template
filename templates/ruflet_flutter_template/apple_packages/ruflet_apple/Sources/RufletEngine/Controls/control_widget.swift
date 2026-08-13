import RufletProtocol
import SwiftUI

/// Resolves a Ruflet control through the registered renderer extensions.
/// Unknown controls are programmer/protocol errors; the native renderer does
/// not substitute a placeholder or a different rendering engine.
@MainActor
public struct ControlWidget: View {
  @ObservedObject private var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    keyedView
  }

  private var resolvedView: AnyView {
    guard let view = control.backend.extensionRegistry.view(for: control) else {
      preconditionFailure("Unknown Ruflet control: \(control.type)")
    }
    return view
  }

  private var contextualView: some View {
    ControlInheritedNotifier(control: control) {
      resolvedView
    }
  }

  private var controlKey: AnyHashable {
    parsedControlKey.map(AnyHashable.init) ?? AnyHashable(control.id)
  }

  private var parsedControlKey: ControlKey? {
    parseKey(control.value("key"))
  }

  @ViewBuilder
  private var keyedView: some View {
    if case .scroll(let value) = parsedControlKey {
      contextualView
        .id(controlKey)
        .background(RufletScrollTargetMarker(key: value, backend: control.backend))
    } else {
      contextualView.id(controlKey)
    }
  }
}

@MainActor
extension RufletControl {
  public func buildWidgets(
    _ propertyName: String,
    visibleOnly: Bool = true,
    notifyParent: Bool = false
  ) -> [AnyView] {
    children(propertyName, visibleOnly: visibleOnly).map { child in
      child.notifyParent = notifyParent
      return AnyView(ControlWidget(control: child))
    }
  }

  public func buildWidget(
    _ propertyName: String,
    visibleOnly: Bool = true,
    notifyParent: Bool = false
  ) -> AnyView? {
    guard let child = child(propertyName, visibleOnly: visibleOnly) else { return nil }
    child.notifyParent = notifyParent
    return AnyView(ControlWidget(control: child))
  }

  public func buildTextOrWidget(
    _ propertyName: String,
    visibleOnly: Bool = true,
    notifyParent: Bool = false,
    required: Bool = false
  ) -> AnyView? {
    if let child = buildWidget(
      propertyName,
      visibleOnly: visibleOnly,
      notifyParent: notifyParent
    ) {
      return child
    }
    if let text = string(propertyName) {
      return AnyView(Text(text))
    }
    if required {
      return AnyView(
        ErrorControl("Error displaying \(type)", description: "\(propertyName) must be specified"))
    }
    return nil
  }
}

@MainActor
struct RufletSystemIcon: View {
  let code: Int
  @EnvironmentObject private var registry: RufletExtensionRegistry

  var body: some View {
    RufletAppleIconView.registered(icon: resolvedIcon)
  }

  private var resolvedIcon: RufletAppleIcon {
    guard let icon = registry.appleIcon(for: code) else {
      preconditionFailure("Unknown Ruflet icon code: \(code)")
    }
    return icon
  }
}

@MainActor
extension RufletControl {
  public func buildIconOrWidget(
    _ propertyName: String,
    visibleOnly: Bool = true,
    notifyParent: Bool = false,
    color: Color? = nil
  ) -> AnyView? {
    if let child = buildWidget(
      propertyName,
      visibleOnly: visibleOnly,
      notifyParent: notifyParent
    ) {
      return child
    }
    guard let code = integer(propertyName) else { return nil }
    return AnyView(RufletSystemIcon(code: code).foregroundStyle(color ?? .primary))
  }
}
