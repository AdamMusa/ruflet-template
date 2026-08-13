import RufletEngine

@MainActor
public struct RufletFlashlightExtension: RufletExtension {
  public init() {}

  public var renderedControlTypes: Set<String> { [] }
  public var serviceControlTypes: Set<String> { RufletFlashlight.controlTypes }

  public func createService(for control: RufletControl) -> RufletService? {
    control.type == "Flashlight" ? FlashlightService(control: control) : nil
  }
}
