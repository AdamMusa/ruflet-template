import SwiftUI

enum RufletNativeSwitchValueUpdate: Equatable {
  case none
  case immediate(Bool)
  case animated(Bool)
}

/// Keeps renderer refreshes from cancelling the motion already owned by the
/// native UISwitch. The first model value is configuration; every later
/// model-driven value change is a native animated state change.
func rufletNativeSwitchValueUpdate(
  current: Bool,
  requested: Bool,
  hasAppliedInitialValue: Bool
) -> RufletNativeSwitchValueUpdate {
  guard current != requested else { return .none }
  return hasAppliedInitialValue ? .animated(requested) : .immediate(requested)
}

#if os(iOS)
import UIKit

/// Public `UISwitch` bridge used by both Flet Switch wire types on iOS.
/// Defaults remain nil so UIKit chooses its current system colors and motion.
@MainActor
struct RufletNativeSwitch: UIViewRepresentable {
  let value: Bool
  let enabled: Bool
  let onTintColor: Color?
  let offTintColor: Color?
  let thumbTintColor: Color?
  let accessibilityLabel: String?
  let onChange: (Bool) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

  func makeUIView(context: Context) -> RufletUIKitSwitch {
    let control = RufletUIKitSwitch(frame: .zero)
    control.addTarget(
      context.coordinator,
      action: #selector(Coordinator.changed(_:)),
      for: .valueChanged)
    return control
  }

  func updateUIView(_ control: RufletUIKitSwitch, context: Context) {
    context.coordinator.onChange = onChange
    if control.isEnabled != enabled { control.isEnabled = enabled }
    switch rufletNativeSwitchValueUpdate(
      current: control.isOn,
      requested: value,
      hasAppliedInitialValue: context.coordinator.hasAppliedInitialValue)
    {
    case .none:
      break
    case let .immediate(next):
      control.setOn(next, animated: false)
    case let .animated(next):
      control.setOn(next, animated: true)
    }
    context.coordinator.hasAppliedInitialValue = true

    let nextOnTintColor = onTintColor.map(UIColor.init)
    let nextOffTintColor = offTintColor.map(UIColor.init)
    let nextThumbTintColor = thumbTintColor.map(UIColor.init)
    if control.onTintColor != nextOnTintColor {
      control.onTintColor = nextOnTintColor
    }
    if control.rufletOffTintColor != nextOffTintColor {
      control.rufletOffTintColor = nextOffTintColor
    }
    if control.thumbTintColor != nextThumbTintColor {
      control.thumbTintColor = nextThumbTintColor
    }
    control.accessibilityLabel = accessibilityLabel
    control.accessibilityValue = value ? "on" : "off"
  }

  @MainActor
  final class Coordinator: NSObject {
    var onChange: (Bool) -> Void
    var hasAppliedInitialValue = false
    init(onChange: @escaping (Bool) -> Void) { self.onChange = onChange }

    @objc func changed(_ control: UISwitch) {
      let next = control.isOn
      control.accessibilityValue = next ? "on" : "off"
      // UISwitch begins its native thumb animation before delivering
      // valueChanged. Mutating the observed protocol control synchronously
      // from that UIKit callback re-enters SwiftUI's AttributeGraph and can
      // rebuild the representable mid-animation. Commit on the next main-loop
      // turn so UIKit owns one uninterrupted transition.
      DispatchQueue.main.async { [weak self] in
        self?.onChange(next)
      }
    }
  }
}

@MainActor
final class RufletUIKitSwitch: UISwitch {
  var rufletOffTintColor: UIColor? {
    didSet { setNeedsLayout() }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Keep the inactive track behind UIKit's animated on-track instead of
    // inserting/removing it as `isOn` flips. That lets UISwitch perform one
    // uninterrupted native cross-fade and thumb movement.
    backgroundColor = rufletOffTintColor ?? .clear
    layer.cornerRadius = rufletOffTintColor == nil ? 0 : bounds.height / 2
  }
}
#endif
