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
