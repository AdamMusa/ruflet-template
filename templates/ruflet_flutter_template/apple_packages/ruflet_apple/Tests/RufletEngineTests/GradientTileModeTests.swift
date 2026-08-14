import SwiftUI
import Testing
@testable import RufletEngine

@Suite("Pinned Flet gradient tile modes")
struct GradientTileModeTests {
  @Test("Every Flet tile mode survives parsing")
  func parsesEveryTileMode() throws {
    for tileMode in RufletTileMode.allCases {
      let parsed = try #require(parseGradient([
        "_type": "linear",
        "colors": ["#ff0000", "#0000ff"],
        "tile_mode": tileMode.rawValue,
      ]))
      guard case .linear(_, _, _, let actual) = parsed else {
        Issue.record("Expected a linear gradient")
        continue
      }
      #expect(actual == tileMode)
    }
  }

  @Test("Missing and invalid modes use Flutter's clamp default")
  func defaultsToClamp() throws {
    for rawMode: String? in [nil, "unknown"] {
      var value: [String: Any] = [
        "_type": "radial",
        "colors": ["#ff0000", "#0000ff"],
      ]
      if let rawMode { value["tile_mode"] = rawMode }
      let parsed = try #require(parseGradient(value))
      guard case .radial(_, _, _, let actual) = parsed else {
        Issue.record("Expected a radial gradient")
        continue
      }
      #expect(actual == .clamp)
    }
  }

  @Test("Sweep gradients retain non-clamp modes")
  func sweepRetainsMode() throws {
    let parsed = try #require(parseGradient([
      "_type": "sweep",
      "colors": ["#ff0000", "#0000ff"],
      "tile_mode": "mirror",
      "start_angle": 0.25,
      "end_angle": 1.75,
    ]))
    guard case .sweep(_, _, let start, let end, let tileMode) = parsed else {
      Issue.record("Expected a sweep gradient")
      return
    }
    #expect(start == 0.25)
    #expect(end == 1.75)
    #expect(tileMode == .mirror)
  }
}
