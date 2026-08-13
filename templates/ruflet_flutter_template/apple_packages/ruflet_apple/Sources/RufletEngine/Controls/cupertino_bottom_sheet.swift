import SwiftUI

/// Apple-native port of pinned `cupertino_bottom_sheet.dart`.
@MainActor
public struct CupertinoBottomSheetControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    RufletAppleSheetPresenter(control: control, kind: .cupertino)
  }
}
