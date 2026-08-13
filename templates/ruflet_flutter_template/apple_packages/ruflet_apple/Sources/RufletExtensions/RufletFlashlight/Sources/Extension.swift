import RufletEngine

@MainActor
public struct RufletFlashlightExtension: RufletExtension {
  public init() {}

  public func createService(for control: RufletControl) -> RufletService? {
    control.type == "Flashlight" ? FlashlightService(control: control) : nil
  }
}
