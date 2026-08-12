import RufletEngine

/// Mirrors `Control.buildWidget`: unresolved and `visible: false` children are
/// both absent before a Flet control performs its required-slot validation.
enum RufletRequiredContent {
  static func isVisible(_ content: ControlNode?) -> Bool {
    guard let content else { return false }
    return content.bool("visible") != false
  }

  static func validationError(
    contentID: Int?, content: ControlNode?, message: String
  ) -> String? {
    contentID != nil && isVisible(content) ? nil : message
  }
}
