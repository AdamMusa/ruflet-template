import SwiftUI

public enum RufletMarkdownExtensionSet: String, Sendable {
  case commonMark = "commonmark"
  case gitHubWeb = "githubweb"
  case gitHubFlavored = "githubflavored"
}

public enum RufletMarkdownCodeTheme {
  case named(String)
  case styles([String: RufletTextStyle])
}

public struct RufletMarkdownStyleSheet {
  public let values: [String: Any]
  public let blockSpacing: Double
  public let listIndent: Double
  public let paragraphPadding: EdgeInsets

  public func textStyle(_ key: String) -> RufletTextStyle? {
    parseTextStyle(values[key])
  }

  public func padding(_ key: String, _ defaultValue: EdgeInsets = EdgeInsets()) -> EdgeInsets {
    parsePadding(values[key], defaultValue)!
  }
}

public func parseMarkdownExtensionSet(
  _ value: String?, _ defaultValue: RufletMarkdownExtensionSet? = nil
) -> RufletMarkdownExtensionSet? {
  guard let value else { return defaultValue }
  return RufletMarkdownExtensionSet(rawValue: value.lowercased()) ?? defaultValue
}

public func parseMarkdownCodeTheme(_ value: Any?) -> RufletMarkdownCodeTheme? {
  if let name = value as? String { return .named(name.lowercased()) }
  guard let values = rufletDictionary(value) else { return nil }
  let styles = values.reduce(into: [String: RufletTextStyle]()) { result, entry in
    guard let style = parseTextStyle(entry.value) else { return }
    let key: String
    switch entry.key {
    case "class_name": key = "class"
    case "built_in": key = "built_in"
    default: key = entry.key.replacingOccurrences(of: "_", with: "-")
    }
    result[key] = style
  }
  return .styles(styles)
}

public func parseMarkdownStyleSheet(
  _ value: Any?, _ defaultValue: RufletMarkdownStyleSheet? = nil
) -> RufletMarkdownStyleSheet? {
  guard let values = rufletDictionary(value) else { return defaultValue }
  return RufletMarkdownStyleSheet(
    values: values,
    blockSpacing: parseDouble(values["block_spacing"], 8)!,
    listIndent: parseDouble(values["list_indent"], 24)!,
    paragraphPadding: parsePadding(values["p_padding"], EdgeInsets())!)
}

@MainActor
public extension RufletControl {
  func markdownExtensionSet(
    _ propertyName: String, default defaultValue: RufletMarkdownExtensionSet? = nil
  ) -> RufletMarkdownExtensionSet? {
    parseMarkdownExtensionSet(string(propertyName), defaultValue)
  }

  func markdownCodeTheme(_ propertyName: String) -> RufletMarkdownCodeTheme? {
    parseMarkdownCodeTheme(dynamicValue(propertyName))
  }

  func markdownStyleSheet(
    _ propertyName: String, default defaultValue: RufletMarkdownStyleSheet? = nil
  ) -> RufletMarkdownStyleSheet? {
    parseMarkdownStyleSheet(dynamicValue(propertyName), defaultValue)
  }
}
