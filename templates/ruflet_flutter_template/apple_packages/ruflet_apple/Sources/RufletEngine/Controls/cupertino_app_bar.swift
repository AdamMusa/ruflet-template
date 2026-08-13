import SwiftUI

/// Apple-native port of Flet's `CupertinoAppBarControl`.
@MainActor
public struct CupertinoAppBarControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    RufletAppleAppBar(control: control, kind: .cupertino)
  }
}
