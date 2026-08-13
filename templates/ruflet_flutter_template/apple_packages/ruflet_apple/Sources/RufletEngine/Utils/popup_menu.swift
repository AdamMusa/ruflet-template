import SwiftUI

@MainActor
enum RufletPopupMenuEntry {
  case item(RufletControl, checked: Bool?, height: Double, padding: EdgeInsets?)
  case divider(RufletControl)

  var id: Int {
    switch self {
    case .item(let control, _, _, _), .divider(let control): control.id
    }
  }
}

@MainActor
func buildPopupMenuEntries(_ controls: [RufletControl]) -> [RufletPopupMenuEntry] {
  controls.filter { $0.type.caseInsensitiveCompare("PopupMenuItem") == .orderedSame }.map { item in
    let hasContent = item.child("content") != nil || item.string("content") != nil
    let hasIcon = item.child("icon") != nil || item.value("icon") != nil
    guard hasContent || hasIcon else { return .divider(item) }
    return .item(
      item, checked: item.boolean("checked"), height: item.number("height", default: 48)!,
      padding: parsePadding(item.dynamicValue("padding")))
  }
}
