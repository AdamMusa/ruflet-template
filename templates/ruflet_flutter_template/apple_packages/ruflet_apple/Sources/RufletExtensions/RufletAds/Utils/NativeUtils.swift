import RufletEngine
import RufletProtocol
import SwiftUI

enum RufletNativeTemplateType: String {
  case small
  case medium
}

enum RufletNativeTemplateFontStyle: String {
  case normal
  case bold
  case italic
  case monospace
}

struct RufletNativeTemplateTextStyle {
  let size: Double?
  let textColor: Color?
  let backgroundColor: Color?
  let fontStyle: RufletNativeTemplateFontStyle?
}

struct RufletNativeTemplateStyle {
  let templateType: RufletNativeTemplateType
  let mainBackgroundColor: Color?
  let cornerRadius: Double?
  let callToAction: RufletNativeTemplateTextStyle?
  let primary: RufletNativeTemplateTextStyle?
  let secondary: RufletNativeTemplateTextStyle?
  let tertiary: RufletNativeTemplateTextStyle?
}

func rufletNativeTemplateStyle(_ value: RufletValue?) -> RufletNativeTemplateStyle? {
  guard let map = rufletAdsStringMap(value) else { return nil }
  return RufletNativeTemplateStyle(
    templateType: RufletNativeTemplateType(rawValue: map["template_type"]?.text?.lowercased() ?? "") ?? .medium,
    mainBackgroundColor: parseColor(map["main_bgcolor"]?.text),
    cornerRadius: map["corner_radius"]?.number,
    callToAction: rufletNativeTextStyle(map["call_to_action_text_style"]),
    primary: rufletNativeTextStyle(map["primary_text_style"]),
    secondary: rufletNativeTextStyle(map["secondary_text_style"]),
    tertiary: rufletNativeTextStyle(map["tertiary_text_style"]))
}

private func rufletNativeTextStyle(_ value: RufletValue?) -> RufletNativeTemplateTextStyle? {
  guard let map = rufletAdsStringMap(value) else { return nil }
  return RufletNativeTemplateTextStyle(
    size: map["size"]?.number,
    textColor: parseColor(map["color"]?.text),
    backgroundColor: parseColor(map["bgcolor"]?.text),
    fontStyle: RufletNativeTemplateFontStyle(rawValue: map["style"]?.text?.lowercased() ?? ""))
}

#if os(iOS)
import UIKit

extension RufletNativeTemplateTextStyle {
  func apply(to label: UILabel) {
    if let textColor { label.textColor = UIColor(textColor) }
    if let backgroundColor { label.backgroundColor = UIColor(backgroundColor) }
    let size = size ?? label.font.pointSize
    switch fontStyle {
    case .bold: label.font = .boldSystemFont(ofSize: size)
    case .italic: label.font = .italicSystemFont(ofSize: size)
    case .monospace: label.font = .monospacedSystemFont(ofSize: size, weight: .regular)
    case .normal, nil: label.font = .systemFont(ofSize: size)
    }
  }

  func apply(to button: UIButton) {
    if let textColor { button.setTitleColor(UIColor(textColor), for: .normal) }
    if let backgroundColor { button.backgroundColor = UIColor(backgroundColor) }
    let size = size ?? button.titleLabel?.font.pointSize ?? 15
    switch fontStyle {
    case .bold: button.titleLabel?.font = .boldSystemFont(ofSize: size)
    case .italic: button.titleLabel?.font = .italicSystemFont(ofSize: size)
    case .monospace: button.titleLabel?.font = .monospacedSystemFont(ofSize: size, weight: .regular)
    case .normal, nil: button.titleLabel?.font = .systemFont(ofSize: size)
    }
  }
}
#endif
