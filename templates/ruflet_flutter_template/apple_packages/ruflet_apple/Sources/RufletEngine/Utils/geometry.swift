import CoreGraphics

func parseSize(_ value: Any?, _ defaultValue: CGSize? = nil) -> CGSize? {
    guard let value = rufletDictionary(value),
          let width = parseDouble(value["width"]),
          let height = parseDouble(value["height"])
    else {
        return defaultValue
    }
    return CGSize(width: width, height: height)
}

func parseRect(_ value: Any?, _ defaultValue: CGRect? = nil) -> CGRect? {
    guard let value = rufletDictionary(value),
          let left = parseDouble(value["left"]),
          let top = parseDouble(value["top"]),
          let right = parseDouble(value["right"]),
          let bottom = parseDouble(value["bottom"])
    else {
        return defaultValue
    }
    return CGRect(x: left, y: top, width: right - left, height: bottom - top)
}
