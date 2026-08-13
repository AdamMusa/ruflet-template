import Foundation

extension String {
    func trimStart(_ symbol: String) -> String {
        hasPrefix(symbol) ? String(dropFirst(symbol.count)) : self
    }

    func trimEnd(_ symbol: String) -> String {
        hasSuffix(symbol) ? String(dropLast(symbol.count)) : self
    }

    func trimSymbol(_ symbol: String) -> String {
        trimStart(symbol).trimEnd(symbol)
    }

    var isBase64: Bool {
        Data(base64Encoded: stripBase64DataHeader()) != nil
    }

    func stripBase64DataHeader() -> String {
        guard hasPrefix("data:"), let comma = firstIndex(of: ",") else { return self }
        return String(self[index(after: comma)...])
    }
}
