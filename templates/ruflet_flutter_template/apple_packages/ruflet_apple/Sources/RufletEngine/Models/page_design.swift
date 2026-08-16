public enum RufletPageDesign: String, Equatable, Sendable {
  case material, cupertino
}

/// Pinned Flet selects Cupertino widgets only when the control is adaptive and
/// the Page-reported target platform is an Apple platform.
public func rufletPageDesign(
  adaptive: Bool,
  platform: String?,
  defaultPlatform: RufletTargetPlatform
) -> RufletPageDesign {
  guard adaptive else { return .material }
  switch parseTargetPlatform(platform, defaultPlatform) {
  case .iOS, .macOS: return .cupertino
  default: return .material
  }
}
