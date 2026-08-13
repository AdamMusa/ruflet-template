import RufletEngine
import SwiftUI

@MainActor
public struct RufletSpinKitExtension: RufletExtension {
  public init() {}

  public func createView(for control: RufletControl) -> AnyView? {
    guard RufletSpinKit.controlTypes.contains(control.type) else { return nil }
    return AnyView(SpinKitControl(control: control))
  }
}
