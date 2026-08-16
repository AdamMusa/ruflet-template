import SwiftUI

@MainActor
func rufletMenuChildren(
  _ control: RufletControl,
  property: String = "controls"
) -> [RufletControl] {
  control.children(property)
}

/// Apple-native port of pinned Flet `menu_bar.dart`.
@MainActor
public struct MenuBarControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    Group {
      if children.isEmpty {
        ErrorControl("MenuBar must have at minimum one visible child control")
      } else {
        LayoutControl(control: control) {
          HStack(spacing: 0) {
            ForEach(children) { child in
              ControlWidget(control: child)
            }
          }
          .modifier(
            RufletAppleMenuSurfaceModifier(
              style: control.menuStyle("style"),
              rawStyle: control.dynamicValue("style"),
              defaultPadding: EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
          )
          .modifier(RufletMenuClipModifier(behavior: clipBehavior))
        }
      }
    }
  }

  private var children: [RufletControl] {
    rufletMenuChildren(control, property: "controls")
  }
  private var clipBehavior: String {
    control.string("clip_behavior", default: "none")!.lowercased()
  }
}

struct RufletAppleMenuSurfaceModifier: ViewModifier {
  let style: RufletMenuStyle?
  let rawStyle: Any?
  let defaultPadding: EdgeInsets

  func body(content: Content) -> some View {
    let states = Set<RufletWidgetState>()
    let fixed = style?.fixedSize.resolve(states)
    let minimum = style?.minimumSize.resolve(states)
    let maximum = style?.maximumSize.resolve(states)
    let padding = style?.padding.resolve(states) ?? defaultPadding
    let background = style?.backgroundColor.resolve(states) ?? Color.rufletSystemBackground
    let side = style?.side.resolve(states)
    let elevation = max(style?.elevation.resolve(states) ?? 0, 0)
    let shadow = style?.shadowColor.resolve(states) ?? .black.opacity(0.2)
    let radius = menuRadius

    return
      content
      .padding(padding)
      .frame(width: fixed?.width, height: fixed?.height)
      .frame(
        minWidth: minimum?.width,
        maxWidth: maximum?.width,
        minHeight: minimum?.height,
        maxHeight: maximum?.height,
        alignment: style?.alignment?.swiftUI ?? .center
      )
      .background(background)
      .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
      .overlay {
        if let side {
          RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(side.color, lineWidth: side.width)
        }
      }
      .shadow(color: shadow, radius: elevation, y: elevation / 2)
  }

  private var menuRadius: Double {
    guard let details = rufletDictionary(rawStyle),
      let shape = details["shape"]
    else { return 10 }
    let shapeDetails = rufletDictionary(shape)
    return parseBorderRadius(
      shapeDetails?["border_radius"] ?? shapeDetails?["radius"] ?? shape,
      RufletBorderRadius(topLeft: 10, topRight: 10, bottomLeft: 10, bottomRight: 10))?.uniform ?? 10
  }
}

struct RufletMenuClipModifier: ViewModifier {
  let behavior: String

  @ViewBuilder
  func body(content: Content) -> some View {
    if behavior == "none" {
      content
    } else {
      content.clipped(antialiased: behavior.contains("antialias"))
    }
  }
}
