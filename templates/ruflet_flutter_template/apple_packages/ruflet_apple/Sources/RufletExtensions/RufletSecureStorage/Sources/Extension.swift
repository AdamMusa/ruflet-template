import RufletEngine

@MainActor
public struct RufletSecureStorageExtension: RufletExtension {
  public init() {}

  public var renderedControlTypes: Set<String> { [] }
  public var serviceControlTypes: Set<String> { RufletSecureStorage.controlTypes }

  public func createService(for control: RufletControl) -> RufletService? {
    control.type == "SecureStorage" ? SecureStorageService(control: control) : nil
  }
}
