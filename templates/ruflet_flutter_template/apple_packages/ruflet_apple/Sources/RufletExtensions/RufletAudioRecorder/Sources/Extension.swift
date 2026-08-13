import RufletEngine

@MainActor
public struct RufletAudioRecorderExtension: RufletExtension {
  public init() {}

  public var renderedControlTypes: Set<String> { [] }
  public var serviceControlTypes: Set<String> { RufletAudioRecorder.controlTypes }

  public func createService(for control: RufletControl) -> RufletService? {
    control.type == "AudioRecorder" ? AudioRecorderService(control: control) : nil
  }
}
