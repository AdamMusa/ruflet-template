#if os(iOS)
import SwiftUI
import UIKit

/// A public UIKit `UISlider` bridge. Ruflet-specific values and events stay in
/// the coordinator; track, thumb, focus, accessibility, and future appearance
/// changes remain owned by UIKit.
@MainActor
struct RufletNativeSlider: UIViewRepresentable {
  let presentation: RufletSliderPresentation
  let onChange: (Double) -> Void
  let onChangeStart: (Double) -> Void
  let onChangeEnd: (Double) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(
      presentation: presentation,
      onChange: onChange,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd)
  }

  func makeUIView(context: Context) -> RufletUIKitSliderHost {
    let view = RufletUIKitSliderHost()
    view.slider.addTarget(
      context.coordinator, action: #selector(Coordinator.touchDown(_:)), for: .touchDown)
    view.slider.addTarget(
      context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
    view.slider.addTarget(
      context.coordinator,
      action: #selector(Coordinator.touchEnded(_:)),
      for: [.touchUpInside, .touchUpOutside, .touchCancel])
    return view
  }

  func updateUIView(_ view: RufletUIKitSliderHost, context: Context) {
    context.coordinator.update(
      presentation: presentation,
      onChange: onChange,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd)
    view.apply(presentation)
  }

  @MainActor
  final class Coordinator: NSObject {
    var presentation: RufletSliderPresentation
    var onChange: (Double) -> Void
    var onChangeStart: (Double) -> Void
    var onChangeEnd: (Double) -> Void
    private var active = false

    init(
      presentation: RufletSliderPresentation,
      onChange: @escaping (Double) -> Void,
      onChangeStart: @escaping (Double) -> Void,
      onChangeEnd: @escaping (Double) -> Void
    ) {
      self.presentation = presentation
      self.onChange = onChange
      self.onChangeStart = onChangeStart
      self.onChangeEnd = onChangeEnd
    }

    func update(
      presentation: RufletSliderPresentation,
      onChange: @escaping (Double) -> Void,
      onChangeStart: @escaping (Double) -> Void,
      onChangeEnd: @escaping (Double) -> Void
    ) {
      self.presentation = presentation
      self.onChange = onChange
      self.onChangeStart = onChangeStart
      self.onChangeEnd = onChangeEnd
    }

    @objc func touchDown(_ slider: UISlider) {
      beginIfNeeded(slider)
    }

    @objc func changed(_ slider: UISlider) {
      beginIfNeeded(slider)
      let value = presentation.snap(Double(slider.value))
      slider.setValue(Float(value), animated: false)
      slider.accessibilityValue = presentation.label ?? String(value)
      onChange(value)
    }

    @objc func touchEnded(_ slider: UISlider) {
      guard active else { return }
      let value = presentation.snap(Double(slider.value))
      slider.setValue(Float(value), animated: false)
      onChangeEnd(value)
      active = false
    }

    private func beginIfNeeded(_ slider: UISlider) {
      guard !active else { return }
      active = true
      onChangeStart(presentation.value)
    }
  }
}

@MainActor
final class RufletUIKitSliderHost: UIView {
  let secondarySlider = UISlider(frame: .zero)
  let slider = RufletUIKitSlider(frame: .zero)

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    isOpaque = false
    secondarySlider.isUserInteractionEnabled = false
    secondarySlider.isAccessibilityElement = false
    secondarySlider.setThumbImage(UIImage(), for: .normal)
    secondarySlider.setThumbImage(UIImage(), for: .highlighted)
    addSubview(secondarySlider)
    addSubview(slider)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layoutSubviews() {
    super.layoutSubviews()
    secondarySlider.frame = bounds
    slider.frame = bounds
  }

  func apply(_ presentation: RufletSliderPresentation) {
    let minimum = Float(presentation.minimum)
    let maximum = Float(presentation.maximum)
    let value = Float(presentation.value)
    let semantic: UISemanticContentAttribute =
      effectiveUserInterfaceLayoutDirection == .rightToLeft ? .forceRightToLeft : .forceLeftToRight

    [secondarySlider, slider].forEach {
      $0.minimumValue = minimum
      $0.maximumValue = maximum
      $0.semanticContentAttribute = semantic
    }
    slider.interaction = presentation.interaction
    slider.isEnabled = !presentation.disabled
    slider.setValue(value, animated: false)
    slider.minimumTrackTintColor =
      presentation.hasExplicitActiveColor ? UIColor(presentation.activeColor) : nil
    slider.thumbTintColor =
      presentation.hasExplicitThumbColor ? UIColor(presentation.thumbColor) : nil
    slider.accessibilityLabel = presentation.label
    slider.accessibilityValue = presentation.label ?? String(presentation.value)

    if let secondaryValue = presentation.secondaryTrackValue {
      secondarySlider.isHidden = false
      secondarySlider.setValue(Float(secondaryValue), animated: false)
      secondarySlider.minimumTrackTintColor = UIColor(presentation.secondaryActiveColor)
      secondarySlider.maximumTrackTintColor =
        presentation.hasExplicitInactiveColor ? UIColor(presentation.inactiveColor) : nil
      slider.maximumTrackTintColor = .clear
    } else {
      secondarySlider.isHidden = true
      slider.maximumTrackTintColor =
        presentation.hasExplicitInactiveColor ? UIColor(presentation.inactiveColor) : nil
    }
  }
}

@MainActor
final class RufletUIKitSlider: UISlider {
  var interaction = RufletSliderInteraction.tapAndSlide
  private var trackingStartPoint = CGPoint.zero
  private var trackingStartValue: Float = 0

  override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    guard isEnabled else { return false }
    let point = touch.location(in: self)
    trackingStartPoint = point
    trackingStartValue = value
    let thumb = thumbRect(
      forBounds: bounds,
      trackRect: trackRect(forBounds: bounds),
      value: value).insetBy(dx: -12, dy: -12)

    switch interaction {
    case .slideThumb:
      guard thumb.contains(point) else { return false }
      return super.beginTracking(touch, with: event)
    case .slideOnly:
      return true
    case .tapOnly:
      setValue(value(at: point), animated: true)
      sendActions(for: .valueChanged)
      return true
    case .tapAndSlide:
      if !thumb.contains(point) {
        setValue(value(at: point), animated: true)
        sendActions(for: .valueChanged)
      }
      return super.beginTracking(touch, with: event)
    }
  }

  override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    switch interaction {
    case .tapOnly:
      return true
    case .slideOnly:
      let point = touch.location(in: self)
      let track = trackRect(forBounds: bounds)
      guard track.width > 0 else { return true }
      let direction: Float =
        effectiveUserInterfaceLayoutDirection == .rightToLeft ? -1 : 1
      let delta = Float((point.x - trackingStartPoint.x) / track.width) *
        (maximumValue - minimumValue) * direction
      setValue(min(max(trackingStartValue + delta, minimumValue), maximumValue), animated: false)
      sendActions(for: .valueChanged)
      return true
    case .tapAndSlide, .slideThumb:
      return super.continueTracking(touch, with: event)
    }
  }

  private func value(at point: CGPoint) -> Float {
    let track = trackRect(forBounds: bounds)
    guard track.width > 0 else { return minimumValue }
    var fraction = min(max((point.x - track.minX) / track.width, 0), 1)
    if effectiveUserInterfaceLayoutDirection == .rightToLeft { fraction = 1 - fraction }
    return minimumValue + Float(fraction) * (maximumValue - minimumValue)
  }
}

/// iOS has no public dual-thumb range slider. This composes public `UISlider`
/// instances: UIKit still owns both thumbs, tracks, touch behavior,
/// accessibility, and OS-specific appearance.
@MainActor
struct RufletNativeRangeSlider: UIViewRepresentable {
  let presentation: RufletRangeSliderPresentation
  let onChangeStart: () -> Void
  let onChange: (RufletRangeValues) -> Void
  let onChangeEnd: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(
      presentation: presentation,
      onChangeStart: onChangeStart,
      onChange: onChange,
      onChangeEnd: onChangeEnd)
  }

  func makeUIView(context: Context) -> RufletUIKitRangeSliderHost {
    let view = RufletUIKitRangeSliderHost()
    for slider in [view.lowerSlider, view.upperSlider] {
      slider.addTarget(
        context.coordinator, action: #selector(Coordinator.touchDown(_:)), for: .touchDown)
      slider.addTarget(
        context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
      slider.addTarget(
        context.coordinator,
        action: #selector(Coordinator.touchEnded(_:)),
        for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    return view
  }

  func updateUIView(_ view: RufletUIKitRangeSliderHost, context: Context) {
    context.coordinator.update(
      host: view,
      presentation: presentation,
      onChangeStart: onChangeStart,
      onChange: onChange,
      onChangeEnd: onChangeEnd)
    view.apply(presentation)
  }

  @MainActor
  final class Coordinator: NSObject {
    var presentation: RufletRangeSliderPresentation
    var onChangeStart: () -> Void
    var onChange: (RufletRangeValues) -> Void
    var onChangeEnd: () -> Void
    weak var host: RufletUIKitRangeSliderHost?
    private var active = false

    init(
      presentation: RufletRangeSliderPresentation,
      onChangeStart: @escaping () -> Void,
      onChange: @escaping (RufletRangeValues) -> Void,
      onChangeEnd: @escaping () -> Void
    ) {
      self.presentation = presentation
      self.onChangeStart = onChangeStart
      self.onChange = onChange
      self.onChangeEnd = onChangeEnd
    }

    func update(
      host: RufletUIKitRangeSliderHost,
      presentation: RufletRangeSliderPresentation,
      onChangeStart: @escaping () -> Void,
      onChange: @escaping (RufletRangeValues) -> Void,
      onChangeEnd: @escaping () -> Void
    ) {
      self.host = host
      self.presentation = presentation
      self.onChangeStart = onChangeStart
      self.onChange = onChange
      self.onChangeEnd = onChangeEnd
    }

    @objc func touchDown(_ slider: UISlider) {
      guard !active else { return }
      active = true
      onChangeStart()
    }

    @objc func changed(_ slider: UISlider) {
      guard let host else { return }
      if !active { touchDown(slider) }
      let proposed = presentation.snap(Double(slider.value))
      let values: RufletRangeValues
      if slider === host.lowerSlider {
        values = RufletRangeValues(
          start: min(proposed, Double(host.upperSlider.value)),
          end: Double(host.upperSlider.value))
      } else {
        values = RufletRangeValues(
          start: Double(host.lowerSlider.value),
          end: max(proposed, Double(host.lowerSlider.value)))
      }
      host.setValues(values)
      host.updateAccessibility(presentation: presentation, values: values)
      onChange(values)
    }

    @objc func touchEnded(_ slider: UISlider) {
      guard active else { return }
      active = false
      onChangeEnd()
    }
  }
}

@MainActor
final class RufletUIKitRangeSliderHost: UIView {
  let rangeTrack = UISlider(frame: .zero)
  let lowerMaskTrack = UISlider(frame: .zero)
  let lowerSlider = UISlider(frame: .zero)
  let upperSlider = UISlider(frame: .zero)

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    isOpaque = false
    for track in [rangeTrack, lowerMaskTrack] {
      track.isUserInteractionEnabled = false
      track.isAccessibilityElement = false
      track.setThumbImage(UIImage(), for: .normal)
      track.setThumbImage(UIImage(), for: .highlighted)
      addSubview(track)
    }
    for slider in [lowerSlider, upperSlider] {
      slider.minimumTrackTintColor = .clear
      slider.maximumTrackTintColor = .clear
      addSubview(slider)
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layoutSubviews() {
    super.layoutSubviews()
    [rangeTrack, lowerMaskTrack, lowerSlider, upperSlider].forEach { $0.frame = bounds }
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard isUserInteractionEnabled, !isHidden, alpha > 0.01, bounds.contains(point) else {
      return nil
    }
    let lowerX = thumbCenterX(lowerSlider)
    let upperX = thumbCenterX(upperSlider)
    return abs(point.x - lowerX) <= abs(point.x - upperX) ? lowerSlider : upperSlider
  }

  func apply(_ presentation: RufletRangeSliderPresentation) {
    let minimum = Float(presentation.minimum)
    let maximum = Float(presentation.maximum)
    let semantic: UISemanticContentAttribute =
      effectiveUserInterfaceLayoutDirection == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
    for slider in [rangeTrack, lowerMaskTrack, lowerSlider, upperSlider] {
      slider.minimumValue = minimum
      slider.maximumValue = maximum
      slider.semanticContentAttribute = semantic
    }

    isUserInteractionEnabled = !presentation.disabled
    rangeTrack.minimumTrackTintColor =
      presentation.hasExplicitActiveColor ? UIColor(presentation.activeColor) : tintColor
    rangeTrack.maximumTrackTintColor =
      presentation.hasExplicitInactiveColor ? UIColor(presentation.inactiveColor) : .tertiarySystemFill
    lowerMaskTrack.minimumTrackTintColor =
      presentation.hasExplicitInactiveColor ? UIColor(presentation.inactiveColor) : .tertiarySystemFill
    lowerMaskTrack.maximumTrackTintColor = .clear
    setValues(presentation.values)
    updateAccessibility(presentation: presentation, values: presentation.values)
  }

  func setValues(_ values: RufletRangeValues) {
    let start = Float(values.start)
    let end = Float(values.end)
    rangeTrack.setValue(end, animated: false)
    lowerMaskTrack.setValue(start, animated: false)
    lowerSlider.setValue(start, animated: false)
    upperSlider.setValue(end, animated: false)
  }

  func updateAccessibility(
    presentation: RufletRangeSliderPresentation,
    values: RufletRangeValues
  ) {
    lowerSlider.accessibilityLabel = "Lower value"
    lowerSlider.accessibilityValue = presentation.formattedLabel(for: values.start)
    upperSlider.accessibilityLabel = "Upper value"
    upperSlider.accessibilityValue = presentation.formattedLabel(for: values.end)
  }

  private func thumbCenterX(_ slider: UISlider) -> CGFloat {
    slider.thumbRect(
      forBounds: slider.bounds,
      trackRect: slider.trackRect(forBounds: slider.bounds),
      value: slider.value).midX
  }
}
#endif
