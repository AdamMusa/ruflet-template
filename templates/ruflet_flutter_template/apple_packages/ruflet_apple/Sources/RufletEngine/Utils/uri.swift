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

func isURL(_ value: String) -> Bool {
    value.range(of: #"^(https?://|www\.)"#, options: .regularExpression) != nil
}
