import CoreGraphics
import QuartzCore

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

struct RufletFlipDetails: Sendable {
    let flipX: Bool
    let flipY: Bool
    let origin: CGSize?
    let transformHitTests: Bool
}

struct RufletMatrixTransformDetails: Sendable {
    let matrix: CATransform3D
    let origin: CGSize?
    let alignment: RufletAlignment?
    let transformHitTests: Bool
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

func parseFlipDetails(
    _ value: Any?,
    _ defaultValue: RufletFlipDetails? = nil
) -> RufletFlipDetails? {
    guard let value = rufletDictionary(value) else { return defaultValue }
    return RufletFlipDetails(
        flipX: parseBool(value["flip_x"] ?? value["horizontal"], false) ?? false,
        flipY: parseBool(value["flip_y"] ?? value["vertical"], false) ?? false,
        origin: parseOffset(value["origin"]),
        transformHitTests: parseBool(value["transform_hit_tests"], true) ?? true)
}

func parseTransformDetails(
    _ value: Any?,
    _ defaultValue: RufletMatrixTransformDetails? = nil
) -> RufletMatrixTransformDetails? {
    guard let values = rufletDictionary(value) else { return defaultValue }
    let matrixValue = values["matrix"] ?? values
    guard let matrix = rufletMatrix4(matrixValue) else { return defaultValue }
    return RufletMatrixTransformDetails(
        matrix: matrix,
        origin: parseOffset(values["origin"]),
        alignment: parseAlignment(values["alignment"]),
        transformHitTests: parseBool(values["transform_hit_tests"], true) ?? true)
}

func rufletTransformWithOrigin(
    _ transform: CATransform3D,
    origin: CGSize?
) -> CATransform3D {
    guard let origin else { return transform }
    var result = CATransform3DIdentity
    result = CATransform3DTranslate(result, origin.width, origin.height, 0)
    result = CATransform3DConcat(result, transform)
    return CATransform3DTranslate(result, -origin.width, -origin.height, 0)
}

func rufletTransformAround(
    _ transform: CATransform3D,
    point: CGPoint
) -> CATransform3D {
    var result = CATransform3DIdentity
    result = CATransform3DTranslate(result, point.x, point.y, 0)
    result = CATransform3DConcat(result, transform)
    return CATransform3DTranslate(result, -point.x, -point.y, 0)
}

private func rufletMatrix4(_ value: Any?) -> CATransform3D? {
    if let array = rufletArray(value), array.count == 16 {
        var matrix = CATransform3DIdentity
        for row in 0..<4 {
            for column in 0..<4 {
                rufletSetFlutterMatrixEntry(
                    &matrix,
                    row: row,
                    column: column,
                    value: parseDouble(array[row * 4 + column], row == column ? 1 : 0)!)
            }
        }
        return matrix
    }

    guard let values = rufletDictionary(value) else { return nil }
    if values["ctor"] != nil || values["ops"] != nil {
        let constructor = rufletDictionary(values["ctor"])
          ?? ["name": "identity", "args": []]
        guard var matrix = rufletCreateMatrix(constructor) else { return nil }
        for operation in rufletArray(values["ops"]) ?? [] {
            guard let call = rufletDictionary(operation) else { continue }
            rufletApplyMatrixOperation(call, to: &matrix)
        }
        return matrix
    }

    let hasDirectEntries = (0..<4).contains { row in
        (0..<4).contains { column in values["m\(row)\(column)"] != nil }
    }
    guard hasDirectEntries else { return nil }
    var matrix = CATransform3DIdentity
    for row in 0..<4 {
        for column in 0..<4 {
            let key = "m\(row)\(column)"
            if let value = parseDouble(values[key]) {
                rufletSetFlutterMatrixEntry(
                    &matrix, row: row, column: column, value: value)
            }
        }
    }
    return matrix
}

private func rufletCreateMatrix(_ call: [String: Any]) -> CATransform3D? {
    let name = String(describing: call["name"] ?? "identity")
      .replacingOccurrences(of: "-", with: "_").lowercased()
    let args = rufletArray(call["args"]) ?? []
    func number(_ index: Int, _ fallback: Double) -> CGFloat {
        CGFloat(parseDouble(args.indices.contains(index) ? args[index] : nil, fallback)!)
    }
    switch name {
    case "identity": return CATransform3DIdentity
    case "translation_values": return CATransform3DMakeTranslation(number(0, 0), number(1, 0), number(2, 0))
    case "diagonal3_values": return CATransform3DMakeScale(number(0, 1), number(1, 1), number(2, 1))
    case "rotation_z": return CATransform3DMakeRotation(number(0, 0), 0, 0, 1)
    case "skew_x":
        return CATransform3DMakeAffineTransform(
            CGAffineTransform(a: 1, b: 0, c: tan(number(0, 0)), d: 1, tx: 0, ty: 0))
    case "skew_y":
        return CATransform3DMakeAffineTransform(
            CGAffineTransform(a: 1, b: tan(number(0, 0)), c: 0, d: 1, tx: 0, ty: 0))
    default: return nil
    }
}

private func rufletApplyMatrixOperation(
    _ call: [String: Any],
    to matrix: inout CATransform3D
) {
    let name = String(describing: call["name"] ?? "").lowercased()
    let args = rufletArray(call["args"]) ?? []
    func number(_ index: Int, _ fallback: Double) -> CGFloat {
        CGFloat(parseDouble(args.indices.contains(index) ? args[index] : nil, fallback)!)
    }
    switch name {
    case "translate":
        matrix = CATransform3DTranslate(matrix, number(0, 0), number(1, 0), number(2, 0))
    case "scale":
        let x = number(0, 1)
        let y = args.count > 1 ? number(1, 1) : x
        let z = args.count > 2 ? number(2, 1) : (args.count == 1 ? x : 1)
        matrix = CATransform3DScale(matrix, x, y, z)
    case "rotate_z": matrix = CATransform3DRotate(matrix, number(0, 0), 0, 0, 1)
    case "rotate_x": matrix = CATransform3DRotate(matrix, number(0, 0), 1, 0, 0)
    case "rotate_y": matrix = CATransform3DRotate(matrix, number(0, 0), 0, 1, 0)
    case "set_entry":
        let row = parseInt(args.indices.contains(0) ? args[0] : nil, 0) ?? 0
        let column = parseInt(args.indices.contains(1) ? args[1] : nil, 0) ?? 0
        guard (0..<4).contains(row), (0..<4).contains(column) else { return }
        rufletSetFlutterMatrixEntry(
            &matrix, row: row, column: column, value: Double(number(2, 0)))
    case "multiply":
        guard let nested = rufletMatrix4(args.first) else { return }
        matrix = CATransform3DConcat(matrix, nested)
    default:
        break
    }
}

/// Flutter Matrix4 indexes entries as `(row, column)`, while Core Animation's
/// public field layout is transposed for the equivalent visual transform.
private func rufletSetFlutterMatrixEntry(
    _ matrix: inout CATransform3D,
    row: Int,
    column: Int,
    value: Double
) {
    let value = CGFloat(value)
    switch (row, column) {
    case (0, 0): matrix.m11 = value
    case (0, 1): matrix.m21 = value
    case (0, 2): matrix.m31 = value
    case (0, 3): matrix.m41 = value
    case (1, 0): matrix.m12 = value
    case (1, 1): matrix.m22 = value
    case (1, 2): matrix.m32 = value
    case (1, 3): matrix.m42 = value
    case (2, 0): matrix.m13 = value
    case (2, 1): matrix.m23 = value
    case (2, 2): matrix.m33 = value
    case (2, 3): matrix.m43 = value
    case (3, 0): matrix.m14 = value
    case (3, 1): matrix.m24 = value
    case (3, 2): matrix.m34 = value
    case (3, 3): matrix.m44 = value
    default: break
    }
}
