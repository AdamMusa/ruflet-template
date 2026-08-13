import RufletEngine

@MainActor
public struct RufletAudioRecorderExtension: RufletExtension {
  public init() {}

  public func createService(for control: RufletControl) -> RufletService? {
    control.type == "AudioRecorder" ? AudioRecorderService(control: control) : nil
  }
}
