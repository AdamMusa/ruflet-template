public enum RufletWindowResizeEdge: String, CaseIterable, RufletStringEnum {
  case top
  case left
  case right
  case bottom
  case topLeft
  case topRight
  case bottomLeft
  case bottomRight
}

public func parseWindowResizeEdge(
  _ value: String?,
  _ defaultValue: RufletWindowResizeEdge? = nil
) -> RufletWindowResizeEdge? {
  parseEnum(RufletWindowResizeEdge.self, value, defaultValue)
}

public extension RufletControl {
  func windowResizeEdge(
    _ propertyName: String,
    default defaultValue: RufletWindowResizeEdge? = nil
  ) -> RufletWindowResizeEdge? {
    parseWindowResizeEdge(string(propertyName), defaultValue)
  }
}
