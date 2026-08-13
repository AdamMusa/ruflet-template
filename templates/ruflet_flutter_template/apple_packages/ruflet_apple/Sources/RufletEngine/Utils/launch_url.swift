import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct RufletURL: Equatable, Sendable {
    let url: String
    let target: String?

    init(_ url: String, _ target: String? = nil) {
        self.url = url
        self.target = target
    }
}

@MainActor
@discardableResult
func openURL(_ value: RufletURL) async -> Bool {
    guard let url = URL(string: value.url) else { return false }
    #if os(iOS)
    return await UIApplication.shared.open(url)
    #elseif os(macOS)
    return NSWorkspace.shared.open(url)
    #endif
}

func parseURL(_ value: Any?, _ defaultValue: RufletURL? = nil) -> RufletURL? {
    if let value = value as? String {
        return RufletURL(value)
    }
    if let value = rufletDictionary(value), let url = value["url"] as? String {
        return RufletURL(url, value["target"] as? String)
    }
    return defaultValue
}
