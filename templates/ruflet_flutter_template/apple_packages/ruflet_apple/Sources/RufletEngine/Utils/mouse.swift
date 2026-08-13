import SwiftUI

struct RufletMouseCursorModifier: ViewModifier {
    let cursor: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(macOS)
        if let cursor = parseMouseCursor(cursor) {
            content.onHover { hovering in
                if hovering {
                    cursor.push()
                } else {
                    NSCursor.pop()
                }
            }
        } else {
            content
        }
        #elseif os(iOS)
        if cursor == nil || cursor?.lowercased() == "none" {
            content
        } else {
            content.hoverEffect(.highlight)
        }
        #endif
    }
}

#if os(macOS)
import AppKit

private func parseMouseCursor(_ value: String?) -> NSCursor? {
    switch value?.lowercased() {
    case "click": return .pointingHand
    case "text", "verticaltext": return .iBeam
    case "precise", "cell": return .crosshair
    case "forbidden", "nodrop": return .operationNotAllowed
    case "copy": return .dragCopy
    case "disappearing": return .disappearingItem
    case "grab": return .openHand
    case "grabbing", "move", "allscroll": return .closedHand
    case "resizecolumn", "resizeleft", "resizeleftright", "resizeright": return .resizeLeftRight
    case "resizedown", "resizerow", "resizeup", "resizeupdown": return .resizeUpDown
    case "contextmenu": return .contextualMenu
    case "alias", "basic", "help", "progress", "wait", "zoomin", "zoomout": return .arrow
    default: return nil
    }
}
#endif
