import SwiftUI

/// Apple-native port of Flet's `CupertinoTextFieldControl`.
@MainActor
public struct CupertinoTextFieldControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    RufletTextInputControl(control: control, style: .cupertino)
  }
}
