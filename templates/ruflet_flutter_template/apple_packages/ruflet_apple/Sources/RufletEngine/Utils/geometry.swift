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
