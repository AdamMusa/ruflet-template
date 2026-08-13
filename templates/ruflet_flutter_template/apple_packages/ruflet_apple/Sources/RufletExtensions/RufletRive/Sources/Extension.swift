import RufletEngine
import SwiftUI

@MainActor
public struct RufletRiveExtension: RufletExtension {
  public init() {}

  public var renderedControlTypes: Set<String> { RufletRive.controlTypes }

  public func createView(for control: RufletControl) -> AnyView? {
    control.type == "Rive" ? AnyView(RiveControl(control: control)) : nil
  }
}
