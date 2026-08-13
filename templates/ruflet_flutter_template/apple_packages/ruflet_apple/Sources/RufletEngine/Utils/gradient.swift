import SwiftUI

enum RufletTileMode: String, CaseIterable, RufletStringEnum {
    case clamp, repeated, mirror, decal
}

enum RufletGradientSpec {
    case linear(Gradient, start: UnitPoint, end: UnitPoint)
    case radial(Gradient, center: UnitPoint, radius: Double)
    case sweep(Gradient, center: UnitPoint, startAngle: Double, endAngle: Double)
}

func parseGradient(_ value: Any?) -> RufletGradientSpec? {
    guard let value = rufletDictionary(value),
          let rawColors = rufletArray(value["colors"])
    else {
        return nil
    }
    let colors = rawColors.compactMap { parseColor(String(describing: $0)) }
    guard colors.count > 1 else { return nil }
    let stops = (rufletArray(value["stops"]) ?? []).compactMap { parseDouble($0) }
    let gradient: Gradient
    if stops.count == colors.count {
        gradient = Gradient(stops: zip(colors, stops).map { .init(color: $0.0, location: $0.1) })
    } else {
        gradient = Gradient(colors: colors)
    }
    switch value["_type"] as? String {
    case "linear":
        return .linear(
            gradient,
            start: parseAlignment(value["begin"], RufletAlignment(x: -1, y: 0))!.unitPoint,
            end: parseAlignment(value["end"], RufletAlignment(x: 1, y: 0))!.unitPoint
        )
    case "radial":
        return .radial(
            gradient,
            center: parseAlignment(value["center"], .center)!.unitPoint,
            radius: parseDouble(value["radius"], 0.5)!
        )
    case "sweep":
        return .sweep(
            gradient,
            center: parseAlignment(value["center"], .center)!.unitPoint,
            startAngle: parseDouble(value["start_angle"], 0)!,
            endAngle: parseDouble(value["end_angle"], .pi * 2)!
        )
    default:
        return nil
    }
}

struct RufletGradientShapeStyle: View {
    let gradient: RufletGradientSpec

    var body: some View {
        switch gradient {
        case let .linear(gradient, start, end):
            LinearGradient(gradient: gradient, startPoint: start, endPoint: end)
        case let .radial(gradient, center, radius):
            GeometryReader { proxy in
                RadialGradient(
                    gradient: gradient,
                    center: center,
                    startRadius: 0,
                    endRadius: min(proxy.size.width, proxy.size.height) * radius
                )
            }
        case let .sweep(gradient, center, startAngle, endAngle):
            AngularGradient(
                gradient: gradient,
                center: center,
                startAngle: .radians(startAngle),
                endAngle: .radians(endAngle)
            )
        }
    }
}
