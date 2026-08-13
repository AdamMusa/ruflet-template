import CoreGraphics
import Foundation
import RufletProtocol

@MainActor
public final class RufletTestFinder {
  public let id: Int
  public let count: Int
  public let raw: Any

  public init(id: Int, count: Int, raw: Any) {
    self.id = id
    self.count = count
    self.raw = raw
  }

  public var value: RufletValue {
    ["id": .int(Int64(id)), "count": .int(Int64(count))]
  }
}

/// Apple renderer testing surface corresponding exactly to Flet's `Tester`.
@MainActor
public protocol RufletTester: AnyObject {
  func pump(duration: TimeInterval?) async throws
  func pumpAndSettle(duration: TimeInterval?) async throws
  func findByText(_ text: String) -> RufletTestFinder
  func findByTextContaining(_ pattern: String) -> RufletTestFinder
  func findByKey(_ key: RufletValue) throws -> RufletTestFinder
  func findByTooltip(_ value: String) -> RufletTestFinder
  func findByIcon(_ icon: RufletValue) throws -> RufletTestFinder
  func takeScreenshot(_ name: String) async throws -> Data
  func tapAt(_ point: CGPoint) async throws
  func tap(_ finder: RufletTestFinder, index: Int) async throws
  func longPress(_ finder: RufletTestFinder, index: Int) async throws
  func enterText(_ finder: RufletTestFinder, index: Int, text: String) async throws
  func mouseHover(_ finder: RufletTestFinder, index: Int) async throws
  func teardown()
  func waitForTeardown() async
}

@MainActor
public protocol RufletTestingBackend: RufletBackendProtocol {
  var tester: RufletTester? { get }
}
