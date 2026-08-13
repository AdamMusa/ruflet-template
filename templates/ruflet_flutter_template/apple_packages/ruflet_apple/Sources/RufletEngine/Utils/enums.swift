import Foundation

protocol RufletStringEnum: RawRepresentable, CaseIterable where RawValue == String {}

extension RufletStringEnum {
    static func parse(_ value: String?, _ defaultValue: Self? = nil) -> Self? {
        guard let value else { return defaultValue }
        return allCases.first {
            $0.rawValue.caseInsensitiveCompare(value) == .orderedSame
        } ?? defaultValue
    }
}

func parseEnum<T: RufletStringEnum>(
    _ type: T.Type,
    _ value: String?,
    _ defaultValue: T? = nil
) -> T? {
    type.parse(value, defaultValue)
}
