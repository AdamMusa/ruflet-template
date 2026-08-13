import CoreGraphics

public struct RufletPageSizeViewModel: Equatable, Sendable {
  public let breakpoints: [String: Double]
  public let size: CGSize

  public init(size: CGSize, breakpoints: [String: Double]) {
    self.size = size
    self.breakpoints = breakpoints
  }
}
