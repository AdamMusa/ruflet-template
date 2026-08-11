import RufletEngine
import SwiftUI

extension ControlRegistry {
  /// Controls that draw content rather than arrange it.
  static func display(_ node: ControlNode, _ axis: LayoutAxis) -> AnyView? {
    switch node.type {
    case "Text":
      return AnyView(TextControlView(node: node))
    case "TextSpan":
      return AnyView(TextSpanControlView(node: node))
    case "Icon":
      return AnyView(IconControlView(node: node))
    case "Image":
      return AnyView(ImageControlView(node: node))
    case "ProgressBar":
      return AnyView(ProgressBarControlView(node: node))
    case "ProgressRing":
      return AnyView(ProgressRingControlView(node: node))
    case "RufletSpinKit",
      "SpinKitRotatingPlain", "SpinKitDoubleBounce", "SpinKitWave",
      "SpinKitWanderingCubes", "SpinKitFadingFour", "SpinKitFadingCube",
      "SpinKitPulse", "SpinKitChasingDots", "SpinKitThreeBounce", "SpinKitCircle",
      "SpinKitCubeGrid", "SpinKitFadingCircle", "SpinKitRotatingCircle",
      "SpinKitFoldingCube", "SpinKitPumpingHeart", "SpinKitHourGlass",
      "SpinKitPouringHourGlass", "SpinKitPouringHourGlassRefined", "SpinKitFadingGrid",
      "SpinKitRing", "SpinKitRipple", "SpinKitDualRing", "SpinKitSpinningCircle",
      "SpinKitSpinningLines", "SpinKitSquareCircle", "SpinKitThreeInOut",
      "SpinKitDancingSquare", "SpinKitPianoWave", "SpinKitPulsingGrid",
      "SpinKitWaveSpinner":
      return AnyView(SpinKitControlView(node: node))
    case "Rive":
      return AnyView(RiveControlView(node: node))
    case "Lottie":
      return AnyView(LottieControlView(node: node))
    case "CircleAvatar":
      return AnyView(CircleAvatarControlView(node: node))
    case "Badge":
      return AnyView(BadgeControlView(node: node))
    case "Markdown":
      return AnyView(MarkdownControlView(node: node))
    default:
      return nil
    }
  }
}
