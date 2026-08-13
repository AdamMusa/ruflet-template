import Foundation

struct LocaleConfiguration: Equatable, Sendable {
    let supportedLocales: [Locale]
    let locale: Locale?
}

func parseLocaleConfiguration(_ value: Any?) -> LocaleConfiguration {
    let dictionary = rufletDictionary(value)
    let supported = (dictionary?["supported_locales"] as? [Any] ?? []).compactMap { parseLocale($0) }
    return LocaleConfiguration(
        supportedLocales: supported.isEmpty ? [Locale(identifier: "en_US")] : supported,
        locale: parseLocale(dictionary?["current_locale"])
    )
}

func parseLocale(_ value: Any?, _ defaultValue: Locale? = nil) -> Locale? {
    guard let value = rufletDictionary(value) else { return defaultValue }
    let language = (value["language_code"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let country = (value["country_code"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let script = (value["script_code"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let identifier = [language?.isEmpty == false ? language! : "und", script, country]
        .compactMap { $0?.isEmpty == false ? $0 : nil }
        .joined(separator: "_")
    return Locale(identifier: identifier)
}

extension Locale {
    var rufletMap: [String: String?] {
        [
            "language_code": language.languageCode?.identifier,
            "country_code": region?.identifier,
            "script_code": language.script?.identifier,
        ]
    }
}
