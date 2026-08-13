import SwiftUI

/// Parsed representation of Flet's badge property, shared by every Apple control.
struct RufletBadgeConfiguration {
  let label: RufletControl?
  let text: String?
  let isLabelVisible: Bool
  let offset: CGSize
  let alignment: RufletAlignment
  let backgroundColor: Color
  let largeSize: Double?
  let padding: EdgeInsets?
  let smallSize: Double?
  let textColor: Color
}

@MainActor
extension RufletControl {
  func badgeConfiguration(_ propertyName: String) -> RufletBadgeConfiguration? {
    if let badge = child(propertyName, visibleOnly: false) {
      badge.notifyParent = true
      return RufletBadgeConfiguration(
        label: badge.child("label", visibleOnly: false),
        text: badge.string("label"),
        isLabelVisible: badge.boolean("label_visible", default: true),
        offset: parseOffset(badge.dynamicValue("offset")) ?? .zero,
        alignment: parseAlignment(
          badge.dynamicValue("alignment"), RufletAlignment(x: 1, y: -1))!,
        backgroundColor: parseColor(badge.string("bgcolor"), .red)!,
        largeSize: badge.number("large_size"),
        padding: parsePadding(badge.dynamicValue("padding")),
        smallSize: badge.number("small_size"),
        textColor: parseColor(badge.string("text_color"), .white)!)
    }
    guard let text = string(propertyName) else { return nil }
    return RufletBadgeConfiguration(
      label: nil, text: text, isLabelVisible: true, offset: .zero,
      alignment: RufletAlignment(x: 1, y: -1), backgroundColor: .red,
      largeSize: nil, padding: nil, smallSize: nil, textColor: .white)
  }
}
