import CoreText
import Foundation
import RufletProtocol

/// Exact native parser for Flet's `parseFonts()` utility.
///
/// A missing value becomes an empty map. Non-string entries are rejected
/// instead of being silently stringified, matching Dart's
/// `Map<String, String>.from` contract.
func parseFonts(
  _ value: RufletValue?,
  default defaultValue: [String: String]? = nil
) -> [String: String]? {
  guard let value else { return [:] }
  guard let map = value.map else { return defaultValue }
  var fonts: [String: String] = [:]
  for (family, source) in map {
    guard let source = source.text else { return defaultValue }
    fonts[family] = source
  }
  return fonts
}

enum RufletUserFonts {
  static func load(from source: RufletAssetSource) async throws {
    let url: URL
    if source.isFile {
      url = URL(fileURLWithPath: source.path)
    } else {
      guard let remoteURL = URL(string: source.path) else { throw RufletUserFontError.invalidURL }
      let (data, _) = try await URLSession.shared.data(from: remoteURL)
      let temporaryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(remoteURL.pathExtension.isEmpty ? "font" : remoteURL.pathExtension)
      try data.write(to: temporaryURL, options: .atomic)
      url = temporaryURL
    }

    var error: Unmanaged<CFError>?
    guard CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) else {
      if let error { throw error.takeRetainedValue() }
      throw RufletUserFontError.registrationFailed
    }
  }
}

private enum RufletUserFontError: Error {
  case invalidURL
  case registrationFailed
}
