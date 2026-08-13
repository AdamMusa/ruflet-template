import RufletProtocol
import SwiftUI

@MainActor
public struct ContainerControl: View {
  @ObservedObject public var control: RufletControl
  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    let radius = parseBorderRadius(control.dynamicValue("border_radius"), .zero)!
    let border = parseBorder(control.dynamicValue("border"))
    let animation = parseAnimation(control.dynamicValue("animate"))
    let shadow = rufletDictionary(control.dynamicValue("shadow"))
    LayoutControl(control: control) {
      control.buildWidget("content")
        .padding(parsePadding(control.dynamicValue("padding")) ?? EdgeInsets())
        .modifier(
          RufletConstrainedSizeModifier(
            size: rufletSizeContract(for: control),
            alignment: parseAlignment(control.dynamicValue("alignment"), .center)!.swiftUI
          )
        )
        .background(RufletContainerBackground(control: control, radius: radius))
        .overlay {
          if let border {
            RufletBorderOverlay(border: border, radius: radius)
          }
        }
        .clipShape(RufletContainerShape(shape: control.string("shape"), radius: radius))
        .shadow(
          color: parseColor(shadow?["color"] as? String) ?? .clear,
          radius: parseDouble(shadow?["blur_radius"], 0)!,
          x: parseOffset(shadow?["offset"])?.width ?? 0,
          y: parseOffset(shadow?["offset"])?.height ?? 0
        )
        .modifier(RufletContainerInteractionModifier(control: control))
        .allowsHitTesting(!control.boolean("ignore_interactions", default: false))
        .animation(animation?.animation, value: animationSignature)
        .modifier(RufletContainerAnimationCompletion(control: control, animation: animation))
    }
  }

  private var animationSignature: String {
    ["width", "height", "bgcolor", "padding", "margin", "alignment", "border_radius"]
      .map { control.dynamicValue($0).map(String.init(describing:)) ?? "nil" }
      .joined(separator: "|")
  }
}

@MainActor
private struct RufletContainerBackground: View {
  @ObservedObject var control: RufletControl
  let radius: RufletBorderRadius

  var body: some View {
    Group {
      if let gradient = parseGradient(control.dynamicValue("gradient")) {
        RufletGradientShapeStyle(gradient: gradient)
      } else {
        parseColor(control.string("bgcolor")) ?? .clear
      }
    }
    .clipShape(RufletContainerShape(shape: control.string("shape"), radius: radius))
  }
}

private struct RufletContainerShape: Shape {
  let shape: String?
  let radius: RufletBorderRadius

  func path(in rect: CGRect) -> Path {
    if shape?.lowercased() == "circle" {
      return Circle().path(in: rect)
    }
    return RufletCornerShape(radius: radius).path(in: rect)
  }
}

@MainActor
private struct RufletContainerInteractionModifier: ViewModifier {
  @ObservedObject var control: RufletControl
  @State private var tapDownSent = false

  func body(content: Content) -> some View {
    content
      .contentShape(Rectangle())
      .onTapGesture(perform: tapped)
      .onLongPressGesture {
        if enabled("long_press") { control.triggerEvent("long_press") }
      }
      .onHover { hovering in
        if enabled("hover") { control.triggerEvent("hover", data: .bool(hovering)) }
      }
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            guard !tapDownSent, enabled("tap_down") else { return }
            tapDownSent = true
            control.triggerEvent(
              "tap_down",
              data: [
                "k": .string("touch"),
                "l": ["x": .double(value.location.x), "y": .double(value.location.y)],
                "g": ["x": .double(value.location.x), "y": .double(value.location.y)],
              ])
          }
          .onEnded { _ in tapDownSent = false }
      )
  }

  private func tapped() {
    guard !control.disabled else { return }
    if let url = parseURL(control.dynamicValue("url")) {
      Task { await openURL(url) }
    }
    if enabled("click") { control.triggerEvent("click") }
  }

  private func enabled(_ name: String) -> Bool {
    !control.disabled && control.hasEventHandler(name)
  }
}

@MainActor
private struct RufletContainerAnimationCompletion: ViewModifier {
  @ObservedObject var control: RufletControl
  let animation: ImplicitAnimationDetails?
  @State private var task: Task<Void, Never>?

  func body(content: Content) -> some View {
    content
      .onChange(of: control.properties) { _ in
        guard control.hasEventHandler("animation_end"), let animation else { return }
        task?.cancel()
        task = Task { @MainActor in
          try? await Task.sleep(nanoseconds: rufletSleepNanoseconds(animation.duration))
          guard !Task.isCancelled else { return }
          control.triggerEvent("animation_end", data: .string("container"))
        }
      }
      .onDisappear { task?.cancel() }
  }
}
