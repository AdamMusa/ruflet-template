import RufletEngine
import RufletProtocol
import SwiftUI

/// `Screenshot` — captures its content as PNG bytes.
///
/// Flet's `capture` returns the image to Ruby, so the control has to rasterise
/// the *live* subtree, not rebuild it. `ImageRenderer` does exactly that, which
/// is why this needs a mounted view rather than a service.
struct ScreenshotControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    content
      .rufletCommandHandler(node.id) { call, completion in
        capture(call, completion: completion)
      }
  }

  @ViewBuilder
  private var content: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    } else {
      ControlList(ids: node.childIDs, axis: .vertical)
    }
  }

  private func capture(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
    guard #available(iOS 16.0, macOS 13.0, *) else {
      return completion(
        .failure(RufletServiceError.unavailable("Screenshot capture needs iOS 16 / macOS 13")))
    }

    let renderer = ImageRenderer(
      content:
        content
        .environmentObject(store)
        .environment(\.rufletEvents, events))
    renderer.scale = call.argument("pixel_ratio")?.doubleValue ?? 2

    #if canImport(UIKit)
      guard let data = renderer.uiImage?.pngData() else {
        return completion(.failure(RufletServiceError.failed("The view could not be rasterised")))
      }
    #elseif canImport(AppKit)
      guard let image = renderer.nsImage,
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
      else {
        return completion(.failure(RufletServiceError.failed("The view could not be rasterised")))
      }
    #else
      let data = Data()
    #endif

    completion(.success(.binary([UInt8](data))))
  }
}

/// `Semantics` — the accessibility wrapper.
///
/// Flet's Semantics carries the label, hint, value and a set of traits;
/// SwiftUI's accessibility modifiers are the direct equivalent, so a screen
/// reader hears the same thing it would through the Flutter engine.
struct SemanticsControlView: View {
  let node: ControlNode

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .accessibilityLabel(node.string("label") ?? "")
    .accessibilityHint(node.string("hint_text") ?? "")
    .accessibilityValue(node.string("value") ?? "")
    .accessibilityAddTraits(traits)
    .accessibilityHidden(node.bool("excluded") ?? false)
  }

  private var traits: AccessibilityTraits {
    var traits = AccessibilityTraits()
    if node.bool("button") == true { traits.formUnion(.isButton) }
    if node.bool("header") == true { traits.formUnion(.isHeader) }
    if node.bool("image") == true { traits.formUnion(.isImage) }
    if node.bool("link") == true { traits.formUnion(.isLink) }
    if node.bool("selected") == true { traits.formUnion(.isSelected) }
    return traits
  }
}

/// `MergeSemantics` — presents its subtree as one accessibility element, the
/// way Flutter's widget of the same name does.
struct MergeSemanticsControlView: View {
  let node: ControlNode

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

/// `SelectionArea` — makes the text inside it selectable.
struct SelectionAreaControlView: View {
  let node: ControlNode

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .textSelection(.enabled)
  }
}

/// `TransparentPointer` — visible but not hit-testable, so taps fall through
/// to whatever is beneath it in a Stack.
struct TransparentPointerControlView: View {
  let node: ControlNode

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .allowsHitTesting(false)
  }
}

/// `Shimmer` — a loading placeholder with a highlight sweeping across it.
struct ShimmerControlView: View {
  let node: ControlNode
  @State private var phase: CGFloat = -1

  var body: some View {
    let base = MaterialPalette.color(node.string("color"), default: .gray.opacity(0.3))
    let highlight = MaterialPalette.color(
      node.string("highlight_color"), default: .white.opacity(0.6))

    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .overlay(
      LinearGradient(
        stops: [
          .init(color: base.opacity(0), location: 0),
          .init(color: highlight, location: 0.5),
          .init(color: base.opacity(0), location: 1)
        ],
        startPoint: .leading, endPoint: .trailing)
        .offset(x: phase * 240)
        .blendMode(.plusLighter)
    )
    .mask(
      Group {
        if let contentID = node.controlID(forKey: "content") {
          ControlView(id: contentID, axis: .none)
        }
      }
    )
    .onAppear {
      let period = (node.double("period") ?? 1500) / 1000
      withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) {
        phase = 1
      }
    }
  }
}

/// `ShaderMask` — masks its content with a gradient.
///
/// Flet passes an arbitrary shader; a linear or radial gradient is the part of
/// that surface SwiftUI can express, and it is what the control is used for.
struct ShaderMaskControlView: View {
  let node: ControlNode

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .mask(gradient)
  }

  @ViewBuilder
  private var gradient: some View {
    if let mask = GradientProps.linear(node.props["shader"]) {
      Rectangle().fill(mask)
    } else {
      Rectangle()
    }
  }
}

/// `Hero` — a shared-element transition between screens.
///
/// SwiftUI matches geometry by tag within a namespace, so the control's `tag`
/// becomes the match id. Two screens sharing a namespace animate; a lone Hero
/// simply renders its content, which is the Flutter behaviour too.
struct HeroControlView: View {
  let node: ControlNode
  @Namespace private var namespace

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .matchedGeometryEffect(id: node.string("tag") ?? "hero-\(node.id)", in: namespace)
  }
}

/// `WindowDragArea` — dragging this region moves the window.
struct WindowDragAreaControlView: View {
  let node: ControlNode

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .modifier(WindowDragGesture(enabled: node.bool("maximizable") != false))
  }
}

private struct WindowDragGesture: ViewModifier {
  let enabled: Bool

  func body(content: Content) -> some View {
    #if os(macOS)
      content.gesture(
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
          .onChanged { _ in
            // AppKit already knows how to drag a window from an event; asking
            // it is far more robust than moving the frame by hand.
            guard let window = NSApp.keyWindow, let event = NSApp.currentEvent else { return }
            window.performDrag(with: event)
          })
    #else
      content
    #endif
  }
}

/// `BrowserContextMenu` and `AutofillGroup` — web-only and platform-managed
/// respectively, so they render their content and nothing more.
struct InertWrapperControlView: View {
  let node: ControlNode

  var body: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    } else {
      ControlList(ids: node.childIDs, axis: .vertical)
    }
  }
}
