import RufletProtocol
import SwiftUI

/// Diagnostic counters for renderer work, enabled by `RUFLET_RENDER_COUNTERS`.
/// A control tree should evaluate roughly one body per control per update; a
/// far larger number means SwiftUI is re-evaluating subtrees it could have
/// diffed, which is the shape of a rebuild-storm rather than a slow layout.
@MainActor
public enum RufletRenderCounters {
  public static let enabled =
    ProcessInfo.processInfo.environment["RUFLET_RENDER_COUNTERS"] == "1"
  public static var bodyEvaluations = 0
}

/// Resolves a Ruflet control through the registered renderer extensions.
/// Unknown controls are reported in-place, matching Flet's ErrorControl
/// behavior. A valid-but-unregistered extension must never terminate the app.
@MainActor
public struct ControlWidget: View {
  @ObservedObject private var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    if RufletRenderCounters.enabled { RufletRenderCounters.bodyEvaluations += 1 }
    return keyedView
  }

  private var resolvedView: AnyView {
    guard let view = control.backend.extensionRegistry.view(for: control) else {
      return AnyView(
        ErrorControl(
          "Unknown Ruflet control",
          description: "No native renderer is registered for \(control.type)."))
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
        .modifier(RufletGeometryTrace(control: control))
    } else {
      contextualView.id(controlKey).modifier(RufletGeometryTrace(control: control))
    }
  }
}

private struct RufletGeometryTrace: ViewModifier {
  let control: RufletControl

  @ViewBuilder
  func body(content: Content) -> some View {
    if ProcessInfo.processInfo.environment["RUFLET_GEOMETRY_TRACE"] == "1" {
      content.background {
        GeometryReader { proxy in
          // Report every pass, not just the first: SwiftUI settles
          // measurement-driven layouts over several passes, so an onAppear-only
          // sample shows a transient state rather than the final geometry.
          Color.clear
            .onAppear { report(proxy.frame(in: .global)) }
            .onChange(of: proxy.frame(in: .global), perform: report)
        }
      }
    } else {
      content
    }
  }

  private func report(_ frame: CGRect) {
    print(
      "TRACE \(control.type)#\(control.id) "
        + "x=\(frame.minX) y=\(frame.minY) w=\(frame.width) h=\(frame.height)")
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

  @ViewBuilder
  var body: some View {
    // Flet parses an icon into a nullable `IconData` and hands it to Flutter's
    // `Icon`, which paints nothing when it is null. An unrecognised code is a
    // blank glyph there, never a crash.
    if let icon = registry.appleIcon(for: code) {
      RufletAppleIconView.registered(icon: icon)
    }
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
