import SwiftUI

@MainActor
public struct ImageControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    LayoutControl(control: control) {
      if control.value("src") == nil {
        ErrorControl("Image must have \"src\" specified.")
      } else if let source = parseImageSource(control.dynamicValue("src"), backend: control.backend) {
        image(source)
      } else if let errorContent = control.buildWidget("error_content") {
        errorContent
      } else {
        ErrorControl("A valid src value must be specified.")
      }
    }
  }

  private func image(_ source: RufletImageSource) -> AnyView {
    let fit = parseEnum(RufletImageFit.self, control.string("fit"), .contain)!
    let repeatMode = parseEnum(RufletImageRepeat.self, control.string("repeat"), .noRepeat)!
    let quality = parseEnum(RufletFilterQuality.self, control.string("filter_quality"), .medium)!
    let radius = parseBorderRadius(control.dynamicValue("border_radius"), .zero)!
    let placeholder = placeholderView(fit: fit, repeatMode: repeatMode, quality: quality)
    let fade = parseAnimation(control.dynamicValue("fade_in_animation"))
    let width = control.number("width").map { CGFloat($0) }
    let height = control.number("height").map { CGFloat($0) }

    let sourceView = RufletImageSourceView(
      source: source,
      contentMode: fit.contentMode,
      onError: nil,
      resizingMode: repeatMode.resizingMode,
      interpolation: quality.interpolation,
      antiAlias: control.boolean("anti_alias", default: false),
      tint: parseColor(control.string("color")),
      placeholder: placeholder,
      errorContent: control.buildWidget("error_content"),
      fadeInAnimation: fade)
    let sized = AnyView(sourceView.frame(width: width, height: height))
    let clipped = AnyView(sized.clipShape(RufletCornerShape(radius: radius)))
    return AnyView(clipped
      .accessibilityHidden(control.boolean("exclude_from_semantics", default: false))
      .accessibilityLabel(control.string("semantics_label") ?? "")
      .opacity(control.disabled ? 0.38 : 1))
  }

  private func placeholderView(
    fit: RufletImageFit,
    repeatMode: RufletImageRepeat,
    quality: RufletFilterQuality
  ) -> AnyView? {
    guard let source = parseImageSource(control.dynamicValue("placeholder_src"), backend: control.backend) else {
      return nil
    }
    let placeholderFit = parseEnum(
      RufletImageFit.self,
      control.string("placeholder_fit"),
      fit)!
    return AnyView(RufletImageSourceView(
      source: source,
      contentMode: placeholderFit.contentMode,
      onError: nil,
      resizingMode: repeatMode.resizingMode,
      interpolation: quality.interpolation,
      antiAlias: control.boolean("anti_alias", default: false),
      tint: parseColor(control.string("color"))))
  }
}
