import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

/// `CodeEditor` — a native, monospaced multiline editor.
///
/// The Flutter extension uses a themed editor widget; on Apple the same wire
/// contract maps to `TextEditor`, including live value changes, read-only
/// previews, focus/blur events and the imperative `focus` command.
struct CodeEditorControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @FocusState private var focused: Bool
  @State private var nativeFocused = false
  @State private var selection = NSRange(location: 0, length: 0)
  @State private var folds: [CodeFoldRegion] = []

  var body: some View {
    #if canImport(UIKit) || canImport(AppKit)
      ZStack(alignment: .topLeading) {
        HighlightedCodeTextView(
          text: editorValue,
          focused: $nativeFocused,
          selection: $selection,
          configuration: configuration,
          editable: !configuration.readOnly && !configuration.disabled && folds.isEmpty,
          focusable: !configuration.disabled)
        if configuration.gutter.visible {
          CodeEditorGutterView(
            source: editorValue.wrappedValue,
            configuration: configuration,
            folds: folds,
            toggle: toggleFold)
        }
        if configuration.autocomplete, nativeFocused, !configuration.readOnly,
          let completion = CodeEditorCompletion.current(
            in: source, selection: selection,
            words: configuration.autocompleteWords + CodeLanguageSyntax.resolve(configuration.language).keywords)
        {
          CodeEditorCompletionBar(completion: completion) { word in
            applyCompletion(word, replacing: completion.range)
          }
        }
      }
      .onChange(of: nativeFocused) { isFocused in
        events.fire(node, isFocused ? "focus" : "blur")
      }
      .onChange(of: selection) { range in
        reportSelection(range)
      }
      .modifier(CodeEditorChrome(node: node, dark: isDark))
      .onAppear {
        selection = explicitSelection
        if configuration.autofocus, !configuration.disabled {
          nativeFocused = true
        }
      }
      .rufletCommandHandler(node.id) { call, completion in
        switch call.name {
        case "focus":
          if !configuration.disabled { nativeFocused = true }
          completion(.success(.null))
        case "fold_at":
          toggleFold(at: call.argument("line_number")?.intValue ?? 0)
          completion(.success(.null))
        case "fold_comment_at_line_zero":
          folds = CodeFoldProjection.leadingCommentRegion(in: source).map { [$0] } ?? []
          completion(.success(.null))
        case "fold_imports":
          folds = CodeFoldProjection.importRegions(in: source)
          completion(.success(.null))
        default:
          completion(.failure(rufletUnsupported("CodeEditor", call)))
        }
      }
    #else
    Group {
      if configuration.readOnly {
        ScrollView([.horizontal, .vertical]) {
          Text(node.string("value") ?? "")
            .font(editorFont)
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(configuration.padding)
        }
      } else {
        TextEditor(text: value)
          .font(editorFont)
          .foregroundColor(foreground)
          .focused($focused)
          .padding(configuration.padding)
          .colorScheme(isDark ? .dark : .light)
          .disabled(configuration.disabled || !folds.isEmpty)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(background)
    .onAppear {
      if configuration.autofocus, !configuration.disabled {
        focused = true
      }
    }
    .onChange(of: focused) { isFocused in
      events.fire(node, isFocused ? "focus" : "blur")
    }
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "focus":
        if !configuration.disabled { focused = true }
        completion(.success(.null))
      case "fold_at":
        toggleFold(at: call.argument("line_number")?.intValue ?? 0)
        completion(.success(.null))
      case "fold_comment_at_line_zero":
        folds = CodeFoldProjection.leadingCommentRegion(in: source).map { [$0] } ?? []
        completion(.success(.null))
      case "fold_imports":
        folds = CodeFoldProjection.importRegions(in: source)
        completion(.success(.null))
      default:
        completion(.failure(rufletUnsupported("CodeEditor", call)))
      }
    }
    #endif
  }

  private var value: Binding<String> {
    Binding(
      get: { node.string("value") ?? "" },
      set: { events.commit(node, value: .string($0)) })
  }

  private var source: String { node.string("value") ?? "" }

  private var configuration: CodeEditorConfiguration { CodeEditorConfiguration(node: node) }

  private var editorValue: Binding<String> {
    Binding(
      get: { CodeFoldProjection.project(source, folding: folds) },
      set: { newValue in
        guard folds.isEmpty else { return }
        events.commit(node, value: .string(newValue))
      })
  }

  private var explicitSelection: NSRange {
    CodeEditorSelection.range(from: node.props["selection"], text: source)
  }

  private func reportSelection(_ range: NSRange) {
    guard folds.isEmpty else { return }
    let length = source.utf16.count
    let location = min(max(range.location, 0), length)
    let selectedLength = min(max(range.length, 0), length - location)
    let resolved = NSRange(location: location, length: selectedLength)
    let selectionValue = CodeEditorSelection.value(resolved, text: source)
    events.setLocal(node.id, "selection", selectionValue)
    events.update(node.id, ["selection": selectionValue])
    events.fire(node, "selection_change", data: CodeEditorSelection.event(resolved, text: source))
  }

  private func toggleFold(at line: Int) {
    if let index = folds.firstIndex(where: { $0.startLine == line }) {
      folds.remove(at: index)
      return
    }
    if let region = CodeFoldProjection.blockRegion(in: source, startingAt: line) {
      folds.append(region)
    }
  }

  private func applyCompletion(_ word: String, replacing range: NSRange) {
    guard folds.isEmpty else { return }
    let next = (source as NSString).replacingCharacters(in: range, with: word)
    selection = NSRange(location: range.location + word.utf16.count, length: 0)
    events.commit(node, value: .string(next))
  }

  private var editorFont: Font {
    if let family = configuration.fontFamily {
      return .custom(family, size: configuration.fontSize)
    }
    return .system(size: configuration.fontSize, design: .monospaced)
  }

  private var isDark: Bool { configuration.dark }

  private var background: Color {
    MaterialPalette.color(node.string("bgcolor"), default: isDark ? Color(red: 0.16, green: 0.17, blue: 0.20) : .white)
  }

  private var foreground: Color {
    MaterialPalette.color(node.string("color"), default: isDark ? Color(red: 0.67, green: 0.70, blue: 0.75) : .primary)
  }
}

private struct CodeEditorGutterView: View {
  let source: String
  let configuration: CodeEditorConfiguration
  let folds: [CodeFoldRegion]
  let toggle: (Int) -> Void

  var body: some View {
    VStack(alignment: .trailing, spacing: 0) {
      ForEach(Array(source.components(separatedBy: "\n").indices), id: \.self) { line in
        HStack(spacing: 3) {
          if configuration.gutter.showFoldingHandles {
            Button { toggle(line) } label: {
              Image(systemName: folds.contains { $0.startLine == line } ? "chevron.right" : "chevron.down")
                .opacity(CodeFoldProjection.blockRegion(in: source, startingAt: line) == nil ? 0 : 1)
            }
            .buttonStyle(.plain)
          }
          if configuration.gutter.showErrors {
            Circle()
              .fill(CodeEditorDiagnostics.lines(in: source).contains(line) ? Color.red : Color.clear)
              .frame(width: 5, height: 5)
          }
          if configuration.gutter.showLineNumbers {
            Text(String(line + 1)).monospacedDigit()
          }
        }
        .font(.system(size: configuration.fontSize))
        .foregroundColor(.secondary)
        .frame(height: configuration.fontSize * 1.25)
      }
    }
    .padding(.top, configuration.padding.top)
    .padding(.leading, configuration.padding.leading)
    .frame(width: configuration.gutter.width, alignment: .trailing)
    .background(MaterialPalette.color(configuration.gutter.backgroundToken) ?? Color.clear)
  }
}

struct CodeEditorCompletion: Equatable {
  let range: NSRange
  let suggestions: [String]

  static func current(in source: String, selection: NSRange, words: [String]) -> CodeEditorCompletion? {
    guard selection.length == 0, selection.location <= source.utf16.count else { return nil }
    let prefixSource = (source as NSString).substring(to: selection.location)
    let prefix = prefixSource.components(separatedBy: CharacterSet.alphanumerics.inverted).last ?? ""
    guard !prefix.isEmpty else { return nil }
    let matches = words.filter { $0.hasPrefix(prefix) && $0 != prefix }
    guard !matches.isEmpty else { return nil }
    return CodeEditorCompletion(
      range: NSRange(location: selection.location - prefix.utf16.count, length: prefix.utf16.count),
      suggestions: Array(matches.prefix(8)))
  }
}

enum CodeEditorDiagnostics {
  /// The Flutter plugin obtains parser errors from `CodeController`. Native
  /// Apple text systems do not expose a language parser, but unmatched paired
  /// delimiters are deterministic diagnostics and belong in the same gutter.
  static func lines(in source: String) -> Set<Int> {
    let pairs: [Character: Character] = [")": "(", "]": "[", "}": "{"]
    var stack: [(Character, Int)] = []
    var errors = Set<Int>()
    var line = 0
    var quote: Character?
    var escaped = false
    for character in source {
      if character == "\n" { line += 1 }
      if escaped { escaped = false; continue }
      if character == "\\" { escaped = true; continue }
      if character == "\"" || character == "'" {
        if quote == character { quote = nil } else if quote == nil { quote = character }
        continue
      }
      guard quote == nil else { continue }
      if character == "(" || character == "[" || character == "{" {
        stack.append((character, line))
      } else if let expected = pairs[character] {
        guard stack.last?.0 == expected else { errors.insert(line); continue }
        stack.removeLast()
      }
    }
    errors.formUnion(stack.map(\.1))
    return errors
  }
}

private struct CodeEditorCompletionBar: View {
  let completion: CodeEditorCompletion
  let apply: (String) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack {
        ForEach(completion.suggestions, id: \.self) { word in
          Button(word) { apply(word) }.buttonStyle(.bordered)
        }
      }
      .padding(6)
    }
    .background(.regularMaterial)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct CodeFoldRegion: Equatable {
  let startLine: Int
  let endLine: Int
}

/// A source-preserving projection for the imperative folding API exposed by
/// Flet's CodeEditor. While a projection is folded it is read-only; invoking
/// `fold_at` for the same line expands it without ever replacing the DSL value.
enum CodeFoldProjection {
  static func project(_ source: String, folding regions: [CodeFoldRegion]) -> String {
    guard !regions.isEmpty else { return source }
    let lines = source.components(separatedBy: "\n")
    let byStart = Dictionary(uniqueKeysWithValues: regions.map { ($0.startLine, $0) })
    var output: [String] = []
    var line = 0
    while line < lines.count {
      if let region = byStart[line], region.endLine > line {
        output.append(lines[line] + "  …")
        line = min(region.endLine + 1, lines.count)
      } else {
        output.append(lines[line])
        line += 1
      }
    }
    return output.joined(separator: "\n")
  }

  static func blockRegion(in source: String, startingAt line: Int) -> CodeFoldRegion? {
    let lines = source.components(separatedBy: "\n")
    guard lines.indices.contains(line), line + 1 < lines.count else { return nil }
    let startIndent = indentation(lines[line])
    var end = line
    for index in (line + 1)..<lines.count {
      let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty { end = index; continue }
      if indentation(lines[index]) <= startIndent {
        if trimmed == "end" || trimmed.hasPrefix("}") { end = index }
        break
      }
      end = index
    }
    return end > line ? CodeFoldRegion(startLine: line, endLine: end) : nil
  }

  static func leadingCommentRegion(in source: String) -> CodeFoldRegion? {
    let lines = source.components(separatedBy: "\n")
    var end = -1
    for (index, line) in lines.enumerated() {
      let value = line.trimmingCharacters(in: .whitespaces)
      if value.hasPrefix("#") || value.hasPrefix("//") || value.hasPrefix("/*") || value.hasPrefix("*") {
        end = index
      } else if !value.isEmpty {
        break
      }
    }
    return end > 0 ? CodeFoldRegion(startLine: 0, endLine: end) : nil
  }

  static func importRegions(in source: String) -> [CodeFoldRegion] {
    let lines = source.components(separatedBy: "\n")
    let prefixes = ["import ", "from ", "require ", "require(", "use ", "using "]
    var regions: [CodeFoldRegion] = []
    var start: Int?
    for index in 0...lines.count {
      let isImport = index < lines.count && prefixes.contains {
        lines[index].trimmingCharacters(in: .whitespaces).hasPrefix($0)
      }
      if isImport, start == nil { start = index }
      if !isImport, let first = start {
        if index - 1 > first { regions.append(CodeFoldRegion(startLine: first, endLine: index - 1)) }
        start = nil
      }
    }
    return regions
  }

  private static func indentation(_ line: String) -> Int {
    line.prefix { $0 == " " || $0 == "\t" }.reduce(0) { result, character in
      result + (character == "\t" ? 2 : 1)
    }
  }
}

private struct CodeEditorChrome: ViewModifier {
  let node: ControlNode
  let dark: Bool

  func body(content: Content) -> some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(
        MaterialPalette.color(
          node.string("bgcolor"),
          default: dark ? Color(red: 0.16, green: 0.17, blue: 0.20) : .white))
  }
}

