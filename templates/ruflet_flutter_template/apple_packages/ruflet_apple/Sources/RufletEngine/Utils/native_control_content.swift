import Foundation

/// Returns text only when a wire value can be represented faithfully by an
/// Apple control's native string slot. Rich/custom controls deliberately return
/// nil so the caller can report an explicit protocol error instead of silently
/// losing or approximating protocol content.
@MainActor
func rufletNativePlainText(_ control: RufletControl) -> String? {
  let control = control.unwrapComponent()
  switch control.type {
  case "Text", "SelectableText":
    return control.string("value")
  default:
    return nil
  }
}

@MainActor
func rufletNativePlainText(_ propertyName: String, of control: RufletControl) -> String? {
  if let child = control.child(propertyName) {
    return rufletNativePlainText(child)
  }
  return control.string(propertyName)
}
