import SwiftUI

/// Apple-native port of pinned Flet `cupertino_navigation_bar.dart`.
@MainActor
public struct CupertinoNavigationBarControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    RufletAppleNavigationBar(control: control, kind: .cupertino)
  }
}
