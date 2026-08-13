public struct RufletAssetSource: Equatable, Sendable {
  public let path: String
  public let isFile: Bool

  public init(path: String, isFile: Bool) {
    self.path = path
    self.isFile = isFile
  }
}
