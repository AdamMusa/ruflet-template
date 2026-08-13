import CoreGraphics

struct RotationDetails: Equatable, Sendable {
    let angle: Double
    let alignment: RufletAlignment
}

struct ScaleDetails: Equatable, Sendable {
    let scale: Double?
    let scaleX: Double?
    let scaleY: Double?
    let alignment: RufletAlignment
}

struct OffsetDetails: Equatable, Sendable {
    let x: Double
    let y: Double
}

func parseRotationDetails(
    _ value: Any?,
    _ defaultValue: RotationDetails? = nil
) -> RotationDetails? {
    guard let value else { return defaultValue }
    if rufletDictionary(value) == nil, let angle = parseDouble(value) {
        return RotationDetails(angle: angle, alignment: .center)
    }
    guard let value = rufletDictionary(value) else { return defaultValue }
    return RotationDetails(
        angle: parseDouble(value["angle"], 0)!,
        alignment: parseAlignment(value["alignment"], .center)!
    )
}

func parseScale(_ value: Any?, _ defaultValue: ScaleDetails? = nil) -> ScaleDetails? {
    guard let value else { return defaultValue }
    if rufletDictionary(value) == nil, let scale = parseDouble(value) {
        return ScaleDetails(scale: scale, scaleX: nil, scaleY: nil, alignment: .center)
    }
    guard let value = rufletDictionary(value) else { return defaultValue }
    return ScaleDetails(
        scale: parseDouble(value["scale"]),
        scaleX: parseDouble(value["scale_x"]),
        scaleY: parseDouble(value["scale_y"]),
        alignment: parseAlignment(value["alignment"], .center)!
    )
}

func parseOffset(_ value: Any?, _ defaultValue: CGSize? = nil) -> CGSize? {
    guard value != nil else { return defaultValue }
    let details: OffsetDetails
    if let value = value as? [Any], value.count > 1 {
        details = OffsetDetails(
            x: parseDouble(value[0], 0)!,
            y: parseDouble(value[1], 0)!
        )
    } else if let value = rufletDictionary(value) {
        details = OffsetDetails(
            x: parseDouble(value["x"], 0)!,
            y: parseDouble(value["y"], 0)!
        )
    } else {
        return defaultValue
    }
    return CGSize(width: details.x, height: details.y)
}

func parseOffsetList(_ value: Any?, _ defaultValue: [CGSize]? = nil) -> [CGSize]? {
    guard let values = value as? [Any] else { return defaultValue }
    return values.compactMap { parseOffset($0) }
}
