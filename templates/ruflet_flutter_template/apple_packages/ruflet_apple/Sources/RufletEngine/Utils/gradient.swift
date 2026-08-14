import SwiftUI

enum RufletTileMode: String, CaseIterable, RufletStringEnum {
    case clamp, repeated, mirror, decal
}

enum RufletGradientSpec {
    case linear(Gradient, start: UnitPoint, end: UnitPoint, tileMode: RufletTileMode)
    case radial(Gradient, center: UnitPoint, radius: Double, tileMode: RufletTileMode)
    case sweep(
        Gradient, center: UnitPoint, startAngle: Double, endAngle: Double,
        tileMode: RufletTileMode)
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
    let tileMode = RufletTileMode(
        rawValue: (value["tile_mode"] as? String)?.lowercased() ?? "clamp") ?? .clamp
    switch value["_type"] as? String {
    case "linear":
        return .linear(
            gradient,
            start: parseAlignment(value["begin"], RufletAlignment(x: -1, y: 0))!.unitPoint,
            end: parseAlignment(value["end"], RufletAlignment(x: 1, y: 0))!.unitPoint,
            tileMode: tileMode
        )
    case "radial":
        return .radial(
            gradient,
            center: parseAlignment(value["center"], .center)!.unitPoint,
            radius: parseDouble(value["radius"], 0.5)!,
            tileMode: tileMode
        )
    case "sweep":
        return .sweep(
            gradient,
            center: parseAlignment(value["center"], .center)!.unitPoint,
            startAngle: parseDouble(value["start_angle"], 0)!,
            endAngle: parseDouble(value["end_angle"], .pi * 2)!,
            tileMode: tileMode
        )
    default:
        return nil
    }
}

struct RufletGradientShapeStyle: View {
    let gradient: RufletGradientSpec

    var body: some View {
        switch gradient {
        case let .linear(gradient, start, end, tileMode):
            if tileMode == .clamp {
                LinearGradient(gradient: gradient, startPoint: start, endPoint: end)
            } else {
                tiledCanvas { size in
                    .linearGradient(
                        gradient,
                        startPoint: point(start, in: size),
                        endPoint: point(end, in: size),
                        options: tileMode.options)
                }
            }
        case let .radial(gradient, center, radius, tileMode):
            GeometryReader { proxy in
                if tileMode == .clamp {
                    RadialGradient(
                        gradient: gradient,
                        center: center,
                        startRadius: 0,
                        endRadius: min(proxy.size.width, proxy.size.height) * radius
                    )
                } else {
                    tiledCanvas { size in
                        .radialGradient(
                            gradient,
                            center: point(center, in: size),
                            startRadius: 0,
                            endRadius: min(size.width, size.height) * radius,
                            options: tileMode.options)
                    }
                }
            }
        case let .sweep(gradient, center, startAngle, endAngle, tileMode):
            if tileMode == .clamp {
                AngularGradient(
                    gradient: gradient,
                    center: center,
                    startAngle: .radians(startAngle),
                    endAngle: .radians(endAngle)
                )
            } else {
                tiledCanvas { size in
                    .conicGradient(
                        sweepGradient(
                            gradient, startAngle: startAngle, endAngle: endAngle,
                            tileMode: tileMode),
                        center: point(center, in: size),
                        angle: .radians(startAngle))
                }
            }
        }
    }

    private func tiledCanvas(
        shading: @escaping (CGSize) -> GraphicsContext.Shading
    ) -> some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: shading(size))
        }
    }

    private func point(_ unitPoint: UnitPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: unitPoint.x * size.width, y: unitPoint.y * size.height)
    }

    private func sweepGradient(
        _ gradient: Gradient,
        startAngle: Double,
        endAngle: Double,
        tileMode: RufletTileMode
    ) -> Gradient {
        let revolution = Double.pi * 2
        let span = max(min(abs(endAngle - startAngle), revolution), 0.000_001)
        let cycles = max(Int(ceil(revolution / span)), 1)
        var stops: [Gradient.Stop] = []
        for cycle in 0...cycles {
            let mirrored = tileMode == .mirror && cycle.isMultiple(of: 2) == false
            for stop in gradient.stops {
                let local = mirrored ? 1 - stop.location : stop.location
                let location = (Double(cycle) * span + Double(local) * span) / revolution
                if location <= 1 {
                    stops.append(.init(color: stop.color, location: location))
                }
            }
        }
        if tileMode == .decal {
            stops.append(.init(color: .clear, location: min(span / revolution + 0.000_001, 1)))
        }
        return Gradient(stops: stops.sorted { $0.location < $1.location })
    }
}

private extension RufletTileMode {
    var options: GraphicsContext.GradientOptions {
        switch self {
        case .repeated: [.repeat]
        case .mirror: [.repeat, .mirror]
        case .clamp, .decal: []
        }
    }
}
