import RufletEngine
import SwiftUI

@MainActor
public struct RufletLottieExtension: RufletExtension {
  public init() {}

  public func createView(for control: RufletControl) -> AnyView? {
    control.type == "Lottie" ? AnyView(LottieControl(control: control)) : nil
  }
}
