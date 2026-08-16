import RufletProtocol
import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

@MainActor
public struct ContainerControl: View {
  @ObservedObject public var control: RufletControl
  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    let radius = parseBorderRadius(control.dynamicValue("border_radius"), .zero)!
    let animation = parseAnimation(control.dynamicValue("animate"))
    let presentation = RufletContainerPresentation(control: control, radius: radius)
    LayoutControl(control: control) {
      control.buildWidget("content")
        .padding(parsePadding(control.dynamicValue("padding")) ?? EdgeInsets())
        .modifier(
          RufletConstrainedSizeModifier(
            size: rufletSizeContract(for: control),
            alignment: parseAlignment(control.dynamicValue("alignment"), .center)!.swiftUI,
            fillsAvailableSpace: control.value("alignment") != nil
          )
        )
        .background {
          RufletContainerShadows(presentation: presentation)
          RufletContainerDecoration(
            control: control,
            presentation: presentation,
            foreground: false)
        }
        .overlay {
          RufletContainerDecoration(
            control: control,
            presentation: presentation,
            foreground: true
          )
          .allowsHitTesting(false)
        }
        .modifier(RufletContainerClipModifier(presentation: presentation))
        .modifier(
          RufletContainerInteractionModifier(
            control: control,
            presentation: presentation)
        )
        .modifier(RufletContainerBackdropModifier(presentation: presentation))
        .modifier(RufletContainerColorFilterModifier(filter: presentation.colorFilter))
        .allowsHitTesting(!control.boolean("ignore_interactions", default: false))
        .animation(animation?.animation, value: animationSignature(animated: animation != nil))
        .modifier(RufletContainerAnimationCompletion(control: control, animation: animation))
    }
  }

  /// Materializing seventeen wire values and rendering each through
  /// `String(describing:)` costs more than the rest of a Container's body, and
  /// it is dead work unless `animate` is set: SwiftUI only consults the value
  /// when there is an animation to drive.
  private func animationSignature(animated: Bool) -> String {
    guard animated else { return "" }
    return
      [
        "width", "height", "bgcolor", "padding", "margin", "alignment", "border_radius",
        "border", "shape", "gradient", "blend_mode", "shadow", "image",
        "foreground_decoration", "blur", "color_filter", "clip_behavior",
      ]
      .map { control.dynamicValue($0).map(String.init(describing:)) ?? "nil" }
      .joined(separator: "|")
  }
}

@MainActor
private struct RufletContainerDecoration: View {
  @ObservedObject var control: RufletControl
  let presentation: RufletContainerPresentation
  let foreground: Bool

  var body: some View {
    let decoration = foreground ? presentation.foreground : presentation.background
    ZStack {
      if let decoration {
        Group {
          if let gradient = decoration.gradient {
            RufletGradientShapeStyle(gradient: gradient)
          } else {
            decoration.color ?? .clear
          }
        }
        .blendMode(decoration.blendMode)
        if let image = decoration.image {
          RufletContainerDecorationImageView(image: image)
        }
        if let border = decoration.border {
          RufletBorderOverlay(border: border, radius: decoration.radius)
        }
        ForEach(Array(decoration.shadows.enumerated()), id: \.offset) { _, shadow in
          RufletContainerShape(shape: decoration.shape, radius: decoration.radius)
            .fill(shadow.color)
            .padding(-shadow.spread)
            .blur(radius: shadow.blurRadius)
            .offset(x: shadow.x, y: shadow.y)
        }
      }
    }
    .clipShape(
      RufletContainerShape(
        shape: decoration?.shape ?? presentation.shape,
        radius: decoration?.radius ?? presentation.radius))
  }
}

@MainActor
private struct RufletContainerDecorationImageView: View {
  let image: RufletContainerDecorationImage

  var body: some View {
    RufletImageSourceView(
      source: image.source,
      contentMode: image.fit.contentMode,
      onError: nil,
      resizingMode: image.repeatMode.resizingMode,
      interpolation: image.quality.interpolation,
      antiAlias: image.antiAlias,
      tint: image.tint,
      svgFit: image.fit
    )
    .opacity(image.opacity)
    .scaleEffect(image.scale)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: image.alignment)
    .blendMode(image.colorBlendMode)
    .modifier(RufletContainerInvertModifier(enabled: image.invertColors))
    .flipsForRightToLeftLayoutDirection(image.matchTextDirection)
    .allowsHitTesting(false)
  }
}

typealias RufletContainerDecorationImage = RufletTextFieldDecorationImage

struct RufletContainerBlur: Equatable {
  let sigmaX: CGFloat
  let sigmaY: CGFloat

  var radius: CGFloat { max(sigmaX, sigmaY) }

  init?(_ value: Any?) {
    guard let value else { return nil }
    if let number = parseDouble(value) {
      sigmaX = CGFloat(number)
      sigmaY = CGFloat(number)
    } else if let values = rufletArray(value) {
      sigmaX = CGFloat(parseDouble(values.first, 0)!)
      sigmaY = CGFloat(parseDouble(values.count > 1 ? values[1] : values.first, 0)!)
    } else if let values = rufletDictionary(value) {
      sigmaX = CGFloat(parseDouble(values["sigma_x"], 0)!)
      sigmaY = CGFloat(parseDouble(values["sigma_y"], 0)!)
    } else {
      return nil
    }
  }
}

struct RufletContainerShadow {
  let color: Color
  let blurRadius: CGFloat
  let spread: CGFloat
  let x: CGFloat
  let y: CGFloat

  init?(_ value: Any?) {
    guard let values = rufletDictionary(value) else { return nil }
    let offset = parseOffset(values["offset"], .zero)!
    color = parseColor(values["color"] as? String, .black)!
    blurRadius = CGFloat(parseDouble(values["blur_radius"], 0)!)
    spread = CGFloat(parseDouble(values["spread_radius"], 0)!)
    x = offset.width
    y = offset.height
  }
}

struct RufletContainerColorFilter {
  let color: Color
  let blendMode: BlendMode

  init?(_ value: Any?) {
    guard let values = rufletDictionary(value),
      let color = parseColor(values["color"] as? String),
      let blendMode = rufletContainerBlendMode(values["blend_mode"] as? String)
    else { return nil }
    self.color = color
    self.blendMode = blendMode
  }
}

@MainActor
struct RufletContainerDecorationSpec {
  let shape: String?
  let color: Color?
  let gradient: RufletGradientSpec?
  let radius: RufletBorderRadius
  let border: RufletBorder?
  let shadows: [RufletContainerShadow]
  let blendMode: BlendMode
  let image: RufletContainerDecorationImage?

  init?(_ value: Any?, control: RufletControl) {
    guard let values = rufletDictionary(value) else { return nil }
    shape = values["shape"] as? String
    color = parseColor(values["bgcolor"] as? String)
    gradient = parseGradient(values["gradient"])
    radius = parseBorderRadius(values["border_radius"], .zero)!
    border = parseBorder(values["border"])
    if let shadowValues = rufletArray(values["shadows"]) {
      shadows = shadowValues.compactMap(RufletContainerShadow.init)
    } else {
      shadows = RufletContainerShadow(values["shadows"]).map { [$0] } ?? []
    }
    blendMode = rufletContainerBlendMode(values["blend_mode"] as? String) ?? .normal
    image = RufletContainerDecorationImage(values["image"], control: control)
  }
}

@MainActor
struct RufletContainerPresentation {
  let radius: RufletBorderRadius
  let shape: String?
  let clipBehavior: String
  let background: RufletContainerDecorationSpec?
  let foreground: RufletContainerDecorationSpec?
  let shadows: [RufletContainerShadow]
  let blur: RufletContainerBlur?
  let colorFilter: RufletContainerColorFilter?
  let ink: Bool
  let inkColor: Color

  init(control: RufletControl, radius: RufletBorderRadius) {
    self.radius = radius
    shape = control.string("shape")
    clipBehavior =
      (control.string("clip_behavior")
      ?? (parseBorderRadius(control.dynamicValue("border_radius")) == nil ? "none" : "antialias"))
      .replacingOccurrences(of: "_", with: "")
      .lowercased()
    var backgroundValues: [String: Any] = [:]
    if let value = control.string("shape") { backgroundValues["shape"] = value }
    if let value = control.string("bgcolor") { backgroundValues["bgcolor"] = value }
    if let value = control.dynamicValue("gradient") { backgroundValues["gradient"] = value }
    if let value = control.dynamicValue("border") { backgroundValues["border"] = value }
    if let value = control.dynamicValue("border_radius") {
      backgroundValues["border_radius"] = value
    }
    if let value = control.string("blend_mode") { backgroundValues["blend_mode"] = value }
    if let value = control.dynamicValue("image") { backgroundValues["image"] = value }
    background = RufletContainerDecorationSpec(backgroundValues, control: control)
    foreground = RufletContainerDecorationSpec(
      control.dynamicValue("foreground_decoration"), control: control)
    let shadowValue = control.dynamicValue("shadow")
    if let values = rufletArray(shadowValue) {
      shadows = values.compactMap(RufletContainerShadow.init)
    } else {
      shadows = RufletContainerShadow(shadowValue).map { [$0] } ?? []
    }
    blur = RufletContainerBlur(control.dynamicValue("blur"))
    colorFilter = RufletContainerColorFilter(control.dynamicValue("color_filter"))
    ink = control.boolean("ink", default: false)
    inkColor = parseColor(control.string("ink_color")) ?? Color.accentColor.opacity(0.18)
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
private struct RufletContainerShadows: View {
  let presentation: RufletContainerPresentation

  var body: some View {
    ZStack {
      ForEach(Array(presentation.shadows.enumerated()), id: \.offset) { _, shadow in
        RufletContainerShape(shape: presentation.shape, radius: presentation.radius)
          .fill(shadow.color)
          .padding(-shadow.spread)
          .blur(radius: shadow.blurRadius)
          .offset(x: shadow.x, y: shadow.y)
      }
    }
    .allowsHitTesting(false)
  }
}

private struct RufletContainerClipModifier: ViewModifier {
  let presentation: RufletContainerPresentation

  @ViewBuilder
  func body(content: Content) -> some View {
    if presentation.clipBehavior == "none" {
      content
    } else {
      content.clipShape(
        RufletContainerShape(shape: presentation.shape, radius: presentation.radius),
        style: FillStyle(
          eoFill: false,
          antialiased: presentation.clipBehavior != "hardedge"))
    }
  }
}

@MainActor
private struct RufletContainerInteractionModifier: ViewModifier {
  @ObservedObject var control: RufletControl
  let presentation: RufletContainerPresentation

  @ViewBuilder
  func body(content: Content) -> some View {
    let contract = RufletContainerInteractionContract(control: control)
    if contract.isEnabled {
      interactive(content, contract: contract)
    } else {
      // Pinned Flet does not install MouseRegion/GestureDetector at all when
      // this Container owns no interaction. Keeping the child untouched is
      // essential: an inert parent recognizer must not steal a Button tap.
      content
    }
  }

  private func interactive(_ content: Content, contract: RufletContainerInteractionContract)
    -> some View
  {
    content
      .contentShape(Rectangle())
      .modifier(
        RufletContainerTapModifier(
          enabled: contract.handlesTap || (presentation.ink && contract.handlesTapDown),
          ink: presentation.ink,
          inkColor: presentation.inkColor,
          shape: presentation.shape,
          radius: presentation.radius,
          action: tapped)
      )
      .modifier(
        RufletContainerLongPressModifier(
          enabled: contract.handlesLongPress,
          action: { control.triggerEvent("long_press") })
      )
      .modifier(
        RufletContainerHoverModifier(
          enabled: contract.handlesHover,
          action: { control.triggerEvent("hover", data: .bool($0)) })
      )
      .modifier(
        RufletContainerTapDownModifier(
          enabled: contract.handlesTapDown,
          control: control))
  }

  private func tapped() {
    if let url = parseURL(control.dynamicValue("url")) {
      Task { await openURL(url) }
    }
    if control.hasEventHandler("click") { control.triggerEvent("click") }
  }
}

@MainActor
struct RufletContainerInteractionContract {
  let handlesTap: Bool
  let handlesTapDown: Bool
  let handlesLongPress: Bool
  let handlesHover: Bool
  let isEnabled: Bool

  init(control: RufletControl) {
    let handlesURL = parseURL(control.dynamicValue("url")) != nil
    handlesTap = control.hasEventHandler("click") || handlesURL
    handlesTapDown = control.hasEventHandler("tap_down")
    handlesLongPress = control.hasEventHandler("long_press")
    handlesHover = control.hasEventHandler("hover")
    isEnabled =
      !control.disabled
      && (handlesTap || handlesTapDown || handlesLongPress || handlesHover)
  }
}

private struct RufletContainerTapModifier: ViewModifier {
  let enabled: Bool
  let ink: Bool
  let inkColor: Color
  let shape: String?
  let radius: RufletBorderRadius
  let action: () -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled, ink {
      Button(action: action) { content }
        .buttonStyle(
          RufletContainerInkButtonStyle(
            color: inkColor,
            shape: shape,
            radius: radius))
    } else if enabled {
      content.onTapGesture(perform: action)
    } else {
      content
    }
  }
}

private struct RufletContainerInkButtonStyle: ButtonStyle {
  let color: Color
  let shape: String?
  let radius: RufletBorderRadius

  func makeBody(configuration: Configuration) -> some View {
    configuration.label.overlay {
      if configuration.isPressed {
        RufletContainerShape(shape: shape, radius: radius)
          .fill(color)
          .allowsHitTesting(false)
      }
    }
  }
}

private struct RufletContainerLongPressModifier: ViewModifier {
  let enabled: Bool
  let action: () -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled {
      content.onLongPressGesture(perform: action)
    } else {
      content
    }
  }
}

private struct RufletContainerHoverModifier: ViewModifier {
  let enabled: Bool
  let action: (Bool) -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled {
      content.onHover(perform: action)
    } else {
      content
    }
  }
}

private struct RufletContainerTapDownModifier: ViewModifier {
  let enabled: Bool
  let control: RufletControl
  @State private var sent = false

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled {
      content.simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            guard !sent else { return }
            sent = true
            control.triggerEvent(
              "tap_down",
              data: [
                "k": .string("touch"),
                "l": ["x": .double(value.location.x), "y": .double(value.location.y)],
                "g": ["x": .double(value.location.x), "y": .double(value.location.y)],
              ])
          }
          .onEnded { _ in sent = false })
    } else {
      content
    }
  }
}

private struct RufletContainerBackdropModifier: ViewModifier {
  let presentation: RufletContainerPresentation

  @ViewBuilder
  func body(content: Content) -> some View {
    if let blur = presentation.blur {
      content.background {
        RufletNativeBackdropBlur(radius: blur.radius)
          .clipShape(
            RufletContainerShape(
              shape: presentation.shape,
              radius: presentation.radius))
      }
    } else {
      content
    }
  }
}

private struct RufletContainerColorFilterModifier: ViewModifier {
  let filter: RufletContainerColorFilter?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let filter {
      content
        .overlay(filter.color.blendMode(filter.blendMode))
        .compositingGroup()
    } else {
      content
    }
  }
}

private struct RufletContainerInvertModifier: ViewModifier {
  let enabled: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled { content.colorInvert() } else { content }
  }
}

private func rufletContainerBlendMode(_ value: String?) -> BlendMode? {
  guard let value else { return nil }
  switch value.replacingOccurrences(of: "_", with: "").lowercased() {
  case "clear": return .destinationOut
  case "src", "source": return .normal
  case "srcin", "sourcein": return .sourceAtop
  case "srcatop", "sourceatop": return .sourceAtop
  case "dstover", "destinationover": return .destinationOver
  case "dstout", "destinationout": return .destinationOut
  case "dstatop", "destinationatop": return .destinationOver
  case "xor": return .difference
  case "plus": return .plusLighter
  case "modulate", "multiply": return .multiply
  case "screen": return .screen
  case "overlay": return .overlay
  case "darken": return .darken
  case "lighten": return .lighten
  case "colordodge": return .colorDodge
  case "colorburn": return .colorBurn
  case "hardlight": return .hardLight
  case "softlight": return .softLight
  case "difference": return .difference
  case "exclusion": return .exclusion
  case "hue": return .hue
  case "saturation": return .saturation
  case "color": return .color
  case "luminosity": return .luminosity
  default: return .normal
  }
}

#if os(iOS)
  private struct RufletNativeBackdropBlur: UIViewRepresentable {
    let radius: CGFloat

    func makeUIView(context: Context) -> UIVisualEffectView {
      let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
      view.isUserInteractionEnabled = false
      view.alpha = min(max(radius / 20, 0.05), 1)
      return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
      view.alpha = min(max(radius / 20, 0.05), 1)
    }
  }
#elseif os(macOS)
  private struct RufletNativeBackdropBlur: NSViewRepresentable {
    let radius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
      let view = NSVisualEffectView()
      view.blendingMode = .behindWindow
      view.material = .contentBackground
      view.state = .active
      return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
      view.alphaValue = min(max(radius / 20, 0.05), 1)
    }
  }
#endif

@MainActor
private struct RufletContainerAnimationCompletion: ViewModifier {
  @ObservedObject var control: RufletControl
  let animation: ImplicitAnimationDetails?
  @State private var task: Task<Void, Never>?

  @ViewBuilder
  func body(content: Content) -> some View {
    // `onChange(of: control.properties)` makes SwiftUI deep-compare the whole
    // materialized property map — which contains the control's entire nested
    // subtree — on every render pass. Installing that on every Container makes
    // redraw cost quadratic in tree size. The handler already refuses to fire
    // without both an animation and a subscriber, so only observe then.
    if let animation, control.hasEventHandler("animation_end") {
      content
        .onChange(of: control.properties) { _ in
          task?.cancel()
          task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: rufletSleepNanoseconds(animation.duration))
            guard !Task.isCancelled else { return }
            control.triggerEvent("animation_end", data: .string("container"))
          }
        }
        .onDisappear { task?.cancel() }
    } else {
      content
    }
  }
}
