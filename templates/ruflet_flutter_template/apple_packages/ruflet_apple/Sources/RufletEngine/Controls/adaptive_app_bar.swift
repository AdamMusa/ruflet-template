import SwiftUI

/// The renderer only targets Apple platforms, so adaptive Flet app bars are
/// always resolved to their native Cupertino counterpart.
@MainActor
public struct AdaptiveAppBarControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    CupertinoAppBarControl(control: control)
  }
}
