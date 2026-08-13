import SwiftUI

/// Apple autofill fields in one native view subtree share the same system
/// credential context. This scope preserves Flet's explicit group identity and
/// disposal policy without introducing Android/web configuration.
struct RufletAutofillGroupScope: Equatable, Sendable {
  let controlID: Int
  let disposeAction: RufletAutofillContextAction
}

private struct RufletAutofillGroupScopeKey: EnvironmentKey {
  static let defaultValue: RufletAutofillGroupScope? = nil
}

extension EnvironmentValues {
  var rufletAutofillGroupScope: RufletAutofillGroupScope? {
    get { self[RufletAutofillGroupScopeKey.self] }
    set { self[RufletAutofillGroupScopeKey.self] = newValue }
  }
}

/// Apple-native port of pinned Flet `AutofillGroupControl`.
@MainActor
public struct AutofillGroupControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    if let content = control.buildWidget("content") {
      content
        .environment(\.rufletAutofillGroupScope, scope)
        .accessibilityElement(children: .contain)
    } else {
      ErrorControl("AutofillGroup control has no content.")
    }
  }

  var scope: RufletAutofillGroupScope {
    RufletAutofillGroupScope(
      controlID: control.id,
      disposeAction: parseAutofillContextAction(
        control.string("dispose_action"), .commit) ?? .commit)
  }
}
