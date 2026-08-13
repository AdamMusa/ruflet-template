import Foundation

func getWebPageName(_ url: URL) -> String {
    var path = url.path.trimSymbol("/")
    guard !path.isEmpty else { return path }
    let components = path.split(separator: "/", omittingEmptySubsequences: false)
    if components.count > 1 {
        path = components.prefix(2).joined(separator: "/")
    }
    return path
}

func getAssetURL(_ pageURL: URL, _ assetPath: String) -> URL? {
    assetPath.split(separator: "/").reduce(Optional(pageURL)) { partialURL, component in
        partialURL?.appendingPathComponent(String(component))
    }
}

func getBaseURL(_ pageURL: URL) -> URL? {
    guard var components = URLComponents(url: pageURL, resolvingAgainstBaseURL: false) else {
        return nil
    }
    components.path = ""
    components.query = nil
    components.fragment = nil
    return components.url
}

func isLocalhost(_ url: URL) -> Bool {
    url.host == "localhost" || url.host == "127.0.0.1"
}

func isUDSPath(_ value: String) -> Bool {
    URLComponents(string: value)?.scheme == nil
}

func isURL(_ value: String) -> Bool {
    value.range(of: #"^(https?://|www\.)"#, options: .regularExpression) != nil
}
