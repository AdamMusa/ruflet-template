import RufletEngine

@MainActor
public struct RufletAudioExtension: RufletExtension {
  public init() {}

  public func createService(for control: RufletControl) -> RufletService? {
    control.type == "Audio" ? AudioService(control: control) : nil
  }
}
