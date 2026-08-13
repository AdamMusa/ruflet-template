import SwiftUI

enum RufletAttributionAlignment: String {
  case topLeft = "topleft"
  case topRight = "topright"
  case bottomLeft = "bottomleft"
  case bottomRight = "bottomright"

  init(_ value: String?) {
    let normalized = value?.lowercased().replacingOccurrences(of: "_", with: "")
    self = RufletAttributionAlignment(rawValue: normalized ?? "") ?? .bottomRight
  }

  var swiftUI: Alignment {
    switch self {
    case .topLeft: .topLeading
    case .topRight: .topTrailing
    case .bottomLeft: .bottomLeading
    case .bottomRight: .bottomTrailing
    }
  }
}
