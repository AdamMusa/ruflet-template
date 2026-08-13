import SwiftUI

public struct RufletAlignment: Equatable, Sendable {
  public let x: Double
  public let y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }

  static let center = RufletAlignment(x: 0, y: 0)

  var swiftUI: Alignment {
    Alignment(
      horizontal: x < 0 ? .leading : (x > 0 ? .trailing : .center),
      vertical: y < 0 ? .top : (y > 0 ? .bottom : .center)
    )
  }

  var unitPoint: UnitPoint {
    UnitPoint(x: (x + 1) / 2, y: (y + 1) / 2)
  }
}

public func parseAlignment(_ value: Any?, _ defaultValue: RufletAlignment? = nil)
  -> RufletAlignment?
{
  guard let value = rufletDictionary(value) else { return defaultValue }
  return RufletAlignment(
    x: parseDouble(value["x"], 0)!,
    y: parseDouble(value["y"], 0)!
  )
}

enum RufletMainAxisAlignment: String, CaseIterable, RufletStringEnum {
  case start, end, center, spaceBetween, spaceAround, spaceEvenly
}

enum RufletCrossAxisAlignment: String, CaseIterable, RufletStringEnum {
  case start, end, center, stretch, baseline
}

enum RufletWrapAlignment: String, CaseIterable, RufletStringEnum {
  case start, end, center, spaceBetween, spaceAround, spaceEvenly
}

enum RufletWrapCrossAlignment: String, CaseIterable, RufletStringEnum {
  case start, end, center
}

func rufletMainAxisAlignment(
  _ value: String?, default defaultValue: RufletMainAxisAlignment = .start
) -> RufletMainAxisAlignment {
  switch value?.replacingOccurrences(of: "_", with: "").lowercased() {
  case "end": .end
  case "center": .center
  case "spacebetween": .spaceBetween
  case "spacearound": .spaceAround
  case "spaceevenly": .spaceEvenly
  default: defaultValue
  }
}

func rufletWrapCrossAlignment(
  _ value: String?, default defaultValue: RufletWrapCrossAlignment = .center
) -> RufletWrapCrossAlignment {
  switch value?.lowercased() {
  case "start": .start
  case "end": .end
  case "center": .center
  default: defaultValue
  }
}

struct RufletIntrinsicAxisModifier: ViewModifier {
  let horizontal: Bool
  let vertical: Bool

  func body(content: Content) -> some View {
    content.fixedSize(horizontal: horizontal, vertical: vertical)
  }
}
