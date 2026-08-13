import SwiftUI

/// Apple-native port of pinned Flet `cupertino_checkbox.dart`.
@MainActor
public struct CupertinoCheckboxControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    RufletCheckboxBody(control: control, kind: .cupertino, value: value)
  }

  /// Pinned `CupertinoCheckboxControlState.build` reads `value` itself before
  /// constructing the platform checkbox. Keep that read at this boundary so
  /// the standalone Cupertino wire type has an auditable value contract.
  private var value: Bool? {
    if control.value("value")?.isNull == true,
       control.boolean("tristate", default: false) {
      return nil
    }
    return control.boolean("value", default: false)
  }
}
