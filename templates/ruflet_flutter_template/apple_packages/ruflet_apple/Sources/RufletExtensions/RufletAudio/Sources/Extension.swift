import RufletEngine

@MainActor
public struct RufletAudioExtension: RufletExtension {
  public init() {}

  public var renderedControlTypes: Set<String> { [] }
  public var serviceControlTypes: Set<String> { RufletAudio.controlTypes }

  public func createService(for control: RufletControl) -> RufletService? {
    control.type == "Audio" ? AudioService(control: control) : nil
  }
}
