import Combine
import Foundation

struct RufletCodeSelection: Equatable, Sendable {
  var baseOffset: Int
  var extentOffset: Int

  var range: NSRange {
    NSRange(location: min(baseOffset, extentOffset), length: abs(extentOffset - baseOffset))
  }
}

private struct RufletFold: Equatable {
  var range: NSRange
  let label: String
}

@MainActor
final class FletCodeController: ObservableObject {
  @Published private(set) var fullText: String
  @Published private(set) var visibleText: String
  @Published var selection = RufletCodeSelection(baseOffset: 0, extentOffset: 0)
  @Published var focusRequest = 0
  var language: String
  var autocompletionEnabled = false
  var customWords: [String] = []
  private var folds: [RufletFold] = []

  init(text: String, language: String) {
    fullText = text
    visibleText = text
    self.language = language
  }

  var hasFolds: Bool { !folds.isEmpty }

  func setFullText(_ text: String) {
    guard text != fullText else { return }
    fullText = text
    folds = []
    rebuildProjection()
  }

  func acceptUnfoldedText(_ text: String, selection: RufletCodeSelection) {
    fullText = text
    folds = []
    visibleText = text
    self.selection = selection
  }

  @discardableResult
  func applyVisibleEdit(range: NSRange, replacement: String) -> Bool {
    guard let fullRange = fullRange(forVisibleRange: range) else { return false }
    let oldLength = (fullText as NSString).length
    fullText = (fullText as NSString).replacingCharacters(in: fullRange, with: replacement)
    let delta = (fullText as NSString).length - oldLength
    folds = folds.compactMap { fold in
      if NSMaxRange(fullRange) <= fold.range.location {
        var shifted = fold
        shifted.range.location += delta
        return shifted
      }
      if fullRange.location >= NSMaxRange(fold.range) { return fold }
      return nil
    }
    rebuildProjection()
    let caret = range.location + (replacement as NSString).length
    selection = RufletCodeSelection(baseOffset: caret, extentOffset: caret)
    return true
  }

  func foldCommentAtLineZero() {
    let nsText = fullText as NSString
    guard nsText.length > 0 else { return }
    let lines = lineRanges()
    guard let first = lines.first else { return }
    let firstText = nsText.substring(with: first).trimmingCharacters(in: .whitespacesAndNewlines)
    var end = 0
    if firstText.hasPrefix("//") || firstText.hasPrefix("#") {
      for range in lines {
        let line = nsText.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.hasPrefix("//") || line.hasPrefix("#") || line.isEmpty else { break }
        end = NSMaxRange(range)
      }
    } else if firstText.hasPrefix("/*") {
      for range in lines {
        end = NSMaxRange(range)
        if nsText.substring(with: range).contains("*/") { break }
      }
    }
    guard end > 0 else { return }
    addFold(NSRange(location: 0, length: end), label: "… comment folded …\n")
  }

  func foldImports() {
    let nsText = fullText as NSString
    let imports = lineRanges().filter { range in
      let line = nsText.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
      return line.hasPrefix("import ") || line.hasPrefix("from ") || line.hasPrefix("using ")
        || line.hasPrefix("#include") || line.hasPrefix("package ") || line.hasPrefix("library ")
    }
    guard let first = imports.first, let last = imports.last else { return }
    addFold(
      NSRange(location: first.location, length: NSMaxRange(last) - first.location),
      label: "… \(imports.count) imports folded …\n")
  }

  func foldAt(_ lineNumber: Int) {
    let lines = lineRanges()
    guard lines.indices.contains(lineNumber) else { return }
    let nsText = fullText as NSString
    let opener = lines[lineNumber]
    let openerText = nsText.substring(with: opener)
    let baseIndent = openerText.prefix { $0 == " " || $0 == "\t" }.count
    var braceDepth = openerText.filter { $0 == "{" }.count - openerText.filter { $0 == "}" }.count
    var lastHidden: NSRange?
    for line in lines.dropFirst(lineNumber + 1) {
      let text = nsText.substring(with: line)
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      let indent = text.prefix { $0 == " " || $0 == "\t" }.count
      if braceDepth > 0 {
        braceDepth += text.filter { $0 == "{" }.count - text.filter { $0 == "}" }.count
        if braceDepth <= 0 { break }
        lastHidden = line
      } else {
        if !trimmed.isEmpty, indent <= baseIndent { break }
        lastHidden = line
      }
    }
    guard let lastHidden else { return }
    let start = NSMaxRange(opener)
    guard NSMaxRange(lastHidden) > start else { return }
    addFold(
      NSRange(location: start, length: NSMaxRange(lastHidden) - start),
      label: String(repeating: " ", count: baseIndent + 2) + "… folded …\n")
  }

  func suggestions(at offset: Int) -> [String] {
    guard autocompletionEnabled else { return [] }
    let prefix = wordPrefix(at: offset)
    guard !prefix.isEmpty else { return [] }
    let candidates = Set(customWords + RufletCodeLanguage.keywords(for: language))
    return candidates.filter { $0.lowercased().hasPrefix(prefix.lowercased()) && $0 != prefix }.sorted().prefix(8).map { $0 }
  }

  func lineNumbers() -> [Int] {
    let nsVisible = visibleText as NSString
    if nsVisible.length == 0 { return [1] }
    var result: [Int] = []
    var offset = 0
    while offset < nsVisible.length {
      let fullOffset = fullOffset(forVisibleOffset: offset) ?? offset
      let prefix = (fullText as NSString).substring(to: min(fullOffset, (fullText as NSString).length))
      result.append(prefix.reduce(1) { $1 == "\n" ? $0 + 1 : $0 })
      offset = NSMaxRange(nsVisible.lineRange(for: NSRange(location: offset, length: 0)))
    }
    if visibleText.hasSuffix("\n") {
      let fullOffset = fullOffset(forVisibleOffset: nsVisible.length) ?? nsVisible.length
      let prefix = (fullText as NSString).substring(to: min(fullOffset, (fullText as NSString).length))
      result.append(prefix.reduce(1) { $1 == "\n" ? $0 + 1 : $0 })
    }
    return result
  }

  func foldableLineNumbers() -> Set<Int> {
    let lines = visibleText.split(separator: "\n", omittingEmptySubsequences: false)
    var result = Set<Int>()
    for index in lines.indices.dropLast() {
      let current = lines[index]
      let currentIndent = current.prefix { $0 == " " || $0 == "\t" }.count
      guard !current.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
      guard let next = lines[(index + 1)...].first(where: {
        !$0.trimmingCharacters(in: .whitespaces).isEmpty
      }) else { continue }
      let nextIndent = next.prefix { $0 == " " || $0 == "\t" }.count
      if nextIndent > currentIndent { result.insert(index + 1) }
    }
    return result
  }

  private func wordPrefix(at offset: Int) -> String {
    let text = visibleText as NSString
    var start = min(max(offset, 0), text.length)
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
    while start > 0 {
      let scalar = UnicodeScalar(text.character(at: start - 1))
      guard scalar.map(allowed.contains) == true else { break }
      start -= 1
    }
    return text.substring(with: NSRange(location: start, length: min(offset, text.length) - start))
  }

  private func addFold(_ range: NSRange, label: String) {
    guard range.length > 0, NSMaxRange(range) <= (fullText as NSString).length else { return }
    folds.removeAll { NSIntersectionRange($0.range, range).length > 0 }
    folds.append(RufletFold(range: range, label: label))
    folds.sort { $0.range.location < $1.range.location }
    rebuildProjection()
  }

  private func rebuildProjection() {
    let nsText = fullText as NSString
    var output = ""
    var cursor = 0
    for fold in folds where fold.range.location >= cursor && NSMaxRange(fold.range) <= nsText.length {
      output += nsText.substring(with: NSRange(location: cursor, length: fold.range.location - cursor))
      output += fold.label
      cursor = NSMaxRange(fold.range)
    }
    output += nsText.substring(from: cursor)
    visibleText = output
    let length = (output as NSString).length
    selection.baseOffset = min(selection.baseOffset, length)
    selection.extentOffset = min(selection.extentOffset, length)
  }

  private func fullRange(forVisibleRange range: NSRange) -> NSRange? {
    guard let start = fullOffset(forVisibleOffset: range.location),
          let end = fullOffset(forVisibleOffset: NSMaxRange(range))
    else { return nil }
    return NSRange(location: start, length: max(0, end - start))
  }

  private func fullOffset(forVisibleOffset offset: Int) -> Int? {
    var fullCursor = 0
    var visibleCursor = 0
    for fold in folds {
      let normalLength = fold.range.location - fullCursor
      if offset <= visibleCursor + normalLength { return fullCursor + (offset - visibleCursor) }
      visibleCursor += normalLength
      fullCursor += normalLength
      let labelLength = (fold.label as NSString).length
      if offset < visibleCursor + labelLength { return nil }
      if offset == visibleCursor + labelLength { return NSMaxRange(fold.range) }
      visibleCursor += labelLength
      fullCursor = NSMaxRange(fold.range)
    }
    let remainder = (fullText as NSString).length - fullCursor
    guard offset <= visibleCursor + remainder else { return nil }
    return fullCursor + offset - visibleCursor
  }

  private func lineRanges() -> [NSRange] {
    let text = fullText as NSString
    guard text.length > 0 else { return [] }
    var ranges: [NSRange] = []
    var offset = 0
    while offset < text.length {
      let range = text.lineRange(for: NSRange(location: offset, length: 0))
      ranges.append(range)
      offset = NSMaxRange(range)
    }
    return ranges
  }
}
