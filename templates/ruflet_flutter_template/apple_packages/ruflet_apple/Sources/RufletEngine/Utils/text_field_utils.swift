import Foundation

struct RufletInputFilter: Sendable {
    let expression: NSRegularExpression
    let allow: Bool
    let replacementString: String

    func format(oldValue: String, newValue: String) -> String {
        let range = NSRange(newValue.startIndex..., in: newValue)
        let matches = expression.firstMatch(in: newValue, range: range) != nil
        // Pinned Flet's CustomFilteringTextInputFormatter intentionally accepts
        // the complete edit whenever its pattern matches. The wire `allow` and
        // `replacement_string` fields are retained for model parity, but its
        // overridden formatter does not consult them.
        return matches ? newValue : oldValue
    }
}

struct RufletTextEditSnapshot: Equatable {
    let text: String
    let selection: NSRange
    let composing: NSRange?
}

struct RufletTextEditTransaction: Equatable {
    let oldValue: RufletTextEditSnapshot
    let rawValue: RufletTextEditSnapshot
    let formattedValue: RufletTextEditSnapshot

    var requiresManualMutation: Bool { rawValue != formattedValue }
}

func formatRufletTextEdit(
    current: RufletTextEditSnapshot,
    replacementRange: NSRange,
    replacement: String,
    capitalization: RufletTextCapitalization,
    maxLength: Int?,
    inputFilter: RufletInputFilter?
) -> RufletTextEditTransaction? {
    guard replacementRange.location >= 0,
          replacementRange.length >= 0,
          NSMaxRange(replacementRange) <= current.text.utf16.count,
          let range = Range(replacementRange, in: current.text)
    else { return nil }

    let rawText = current.text.replacingCharacters(in: range, with: replacement)
    let caret = replacementRange.location + replacement.utf16.count
    let rawValue = RufletTextEditSnapshot(
        text: rawText,
        selection: NSRange(location: caret, length: 0),
        composing: current.composing.map {
            rufletRangeAfterReplacement($0, replacementRange: replacementRange, insertedLength: replacement.utf16.count)
        })

    if let inputFilter,
       inputFilter.format(oldValue: current.text, newValue: rawText) == current.text,
       rawText != current.text {
        return nil
    }

    let formattedText = applyCapitalization(rawText, capitalization)
    guard maxLength.map({ formattedText.utf16.count <= $0 }) ?? true else { return nil }
    let formattedValue = RufletTextEditSnapshot(
        text: formattedText,
        selection: rufletMapTextRange(
            rawValue.selection,
            from: rawText,
            capitalization: capitalization,
            maximum: formattedText.utf16.count),
        composing: rawValue.composing.map {
            rufletMapTextRange(
                $0,
                from: rawText,
                capitalization: capitalization,
                maximum: formattedText.utf16.count)
        })
    return RufletTextEditTransaction(
        oldValue: current,
        rawValue: rawValue,
        formattedValue: formattedValue)
}

private func rufletRangeAfterReplacement(
    _ range: NSRange,
    replacementRange: NSRange,
    insertedLength: Int
) -> NSRange {
    let start = rufletOffsetAfterReplacement(
        range.location,
        replacementRange: replacementRange,
        insertedLength: insertedLength,
        trailing: false)
    let end = rufletOffsetAfterReplacement(
        NSMaxRange(range),
        replacementRange: replacementRange,
        insertedLength: insertedLength,
        trailing: true)
    return NSRange(location: min(start, end), length: abs(end - start))
}

private func rufletOffsetAfterReplacement(
    _ offset: Int,
    replacementRange: NSRange,
    insertedLength: Int,
    trailing: Bool
) -> Int {
    if offset < replacementRange.location { return offset }
    if offset > NSMaxRange(replacementRange) {
        return offset + insertedLength - replacementRange.length
    }
    if offset == replacementRange.location, !trailing { return offset }
    return replacementRange.location + insertedLength
}

private func rufletMapTextRange(
    _ range: NSRange,
    from rawText: String,
    capitalization: RufletTextCapitalization,
    maximum: Int
) -> NSRange {
    let start = rufletCapitalizedOffset(
        range.location,
        in: rawText,
        capitalization: capitalization,
        maximum: maximum)
    let end = rufletCapitalizedOffset(
        NSMaxRange(range),
        in: rawText,
        capitalization: capitalization,
        maximum: maximum)
    return NSRange(location: min(start, end), length: abs(end - start))
}

private func rufletCapitalizedOffset(
    _ offset: Int,
    in value: String,
    capitalization: RufletTextCapitalization,
    maximum: Int
) -> Int {
    let clamped = min(max(offset, 0), value.utf16.count)
    let utf16Index = value.utf16.index(value.utf16.startIndex, offsetBy: clamped)
    guard let index = String.Index(utf16Index, within: value) else { return min(clamped, maximum) }
    return min(applyCapitalization(String(value[..<index]), capitalization).utf16.count, maximum)
}

func parseInputFilter(_ value: Any?, _ defaultValue: RufletInputFilter? = nil) -> RufletInputFilter? {
    guard let value = rufletDictionary(value),
          let pattern = value["regex_string"].map(String.init(describing:))
    else {
        return defaultValue
    }
    var options: NSRegularExpression.Options = []
    if parseBool(value["multiline"], false)! { options.insert(.anchorsMatchLines) }
    if !parseBool(value["case_sensitive"], true)! { options.insert(.caseInsensitive) }
    if parseBool(value["dot_all"], false)! { options.insert(.dotMatchesLineSeparators) }
    guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
        return defaultValue
    }
    return RufletInputFilter(
        expression: expression,
        allow: parseBool(value["allow"], true)!,
        replacementString: value["replacement_string"].map(String.init(describing:)) ?? ""
    )
}

enum RufletTextCapitalization: String, CaseIterable, RufletStringEnum {
    case words, sentences, characters, none
}

func applyCapitalization(_ value: String, _ capitalization: RufletTextCapitalization) -> String {
    switch capitalization {
    case .words:
        return value.split(whereSeparator: \.isWhitespace).map(capitalizeFirst).joined(separator: " ")
    case .sentences:
        return value.split(separator: ".", omittingEmptySubsequences: false).map(capitalizeFirst).joined(separator: ".")
    case .characters:
        return value.uppercased()
    case .none:
        return value
    }
}

private func capitalizeFirst<S: StringProtocol>(_ value: S) -> String {
    var result = String(value)
    guard let index = result.firstIndex(where: { !$0.isWhitespace }) else { return result }
    result.replaceSubrange(index...index, with: String(result[index]).uppercased())
    return result
}
