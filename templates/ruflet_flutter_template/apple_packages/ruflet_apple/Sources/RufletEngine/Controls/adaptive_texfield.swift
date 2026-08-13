import SwiftUI

/// Apple-only port of pinned `adaptive_texfield.dart`.
@MainActor
public struct AdaptiveTextFieldControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    CupertinoTextFieldControl(control: control)
  }
}
