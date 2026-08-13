import SwiftUI

/// Apple-native port of pinned Flet `cupertino_checkbox.dart`.
@MainActor
public struct CupertinoCheckboxControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    RufletCheckboxBody(control: control, kind: .cupertino)
  }
}
