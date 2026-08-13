import Foundation

func readFileAsStringIfExists(_ path: String) -> String? {
  let expanded = NSString(string: path).expandingTildeInPath
  guard FileManager.default.fileExists(atPath: expanded) else { return nil }
  return try? String(contentsOfFile: expanded, encoding: .utf8)
}
