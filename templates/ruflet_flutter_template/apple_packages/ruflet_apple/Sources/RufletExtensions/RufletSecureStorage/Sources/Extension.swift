import RufletEngine

@MainActor
public struct RufletSecureStorageExtension: RufletExtension {
  public init() {}

  public func createService(for control: RufletControl) -> RufletService? {
    control.type == "SecureStorage" ? SecureStorageService(control: control) : nil
  }
}
