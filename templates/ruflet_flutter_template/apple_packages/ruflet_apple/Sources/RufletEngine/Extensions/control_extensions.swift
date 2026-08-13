import RufletProtocol

/// The wire-level content forms accepted by Flet's `WidgetFromControl`
/// extension. Rendering remains centralized in `RufletControl.buildWidget`,
/// `buildWidgets`, `buildIconOrWidget`, and `buildTextOrWidget`.
public enum RufletControlPropertyContent: Equatable, Sendable {
  case control
  case icon(Int)
  case text(String)
  case unsupported
}

@MainActor
public extension RufletControl {
  /// Pinned `BaseControl._internals` configuration using the source extension's
  /// explicit name while retaining `internals` for existing Swift callers.
  var internalConfiguration: [String: RufletValue]? { internals }

  /// Classifies the same child/icon/text union consumed by the pinned Dart
  /// widget-building extension without introducing a second renderer path.
  func propertyContent(
    _ propertyName: String,
    visibleOnly: Bool = true
  ) -> RufletControlPropertyContent {
    if child(propertyName, visibleOnly: visibleOnly) != nil { return .control }
    guard let value = value(propertyName) else { return .unsupported }
    if let icon = value.integer { return .icon(icon) }
    if let text = value.text { return .text(text) }
    return .unsupported
  }
}
