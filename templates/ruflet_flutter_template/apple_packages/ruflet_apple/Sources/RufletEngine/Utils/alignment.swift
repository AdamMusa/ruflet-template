import SwiftUI

struct RufletAlignment: Equatable, Sendable {
    let x: Double
    let y: Double

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

func parseAlignment(_ value: Any?, _ defaultValue: RufletAlignment? = nil) -> RufletAlignment? {
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
