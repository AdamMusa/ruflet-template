import Darwin
import Foundation
import RufletProtocol

/// Source-compatible ports of the non-visual helpers used by the pinned Flet
/// client. Keeping them in the engine (rather than reimplementing them in
/// controls) gives the Apple renderer the same URL and networking decisions as
/// `flet/lib/src/utils`.
public enum FletURI {
  public static func webPageName(_ url: URL) -> String {
    let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    guard !path.isEmpty else { return "" }
    return path.split(separator: "/", omittingEmptySubsequences: true)
      .prefix(2)
      .joined(separator: "/")
  }

  public static func assetURL(pageURL: URL, assetPath: String) -> URL? {
    guard var components = URLComponents(url: pageURL, resolvingAgainstBaseURL: false) else {
      return nil
    }
    components.query = nil
    components.fragment = nil
    let pageSegments = components.path.split(separator: "/").map(String.init)
    let assetSegments = assetPath.split(separator: "/").map(String.init)
    components.path = "/" + (pageSegments + assetSegments).joined(separator: "/")
    return components.url
  }

  public static func baseURL(_ pageURL: URL) -> URL? {
    guard var components = URLComponents(url: pageURL, resolvingAgainstBaseURL: false) else {
      return nil
    }
    components.path = ""
    components.query = nil
    components.fragment = nil
    return components.url
  }

  public static func isLocalhost(_ url: URL) -> Bool {
    url.host == "localhost" || url.host == "127.0.0.1"
  }

  /// Dart's `Uri.hasScheme == false` UDS test.
  public static func isUDSPath(_ value: String) -> Bool {
    URLComponents(string: value)?.scheme == nil
  }

  public static func isURL(_ value: String) -> Bool {
    let lowercased = value.lowercased()
    return lowercased.hasPrefix("http://")
      || lowercased.hasPrefix("https://")
      || lowercased.hasPrefix("www.")
  }
}

public enum FletNetworking {
  public enum ResolutionError: Error, Equatable {
    case cannotResolve(String)
  }

  /// Port of Flet's `isPrivateHost()`: IPv4 RFC1918/loopback ranges and, for
  /// IPv6, only link-local and loopback addresses (matching Dart
  /// `InternetAddress.isLinkLocal/isLoopback`).
  public static func isPrivateHost(_ host: String) async throws -> Bool {
    if let address = parsedAddress(host) {
      return address.isPrivate
    }

    var hints = addrinfo(
      ai_flags: AI_ADDRCONFIG,
      ai_family: AF_UNSPEC,
      ai_socktype: SOCK_STREAM,
      ai_protocol: 0,
      ai_addrlen: 0,
      ai_canonname: nil,
      ai_addr: nil,
      ai_next: nil
    )
    var result: UnsafeMutablePointer<addrinfo>?
    guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else {
      throw ResolutionError.cannotResolve(host)
    }
    defer { freeaddrinfo(result) }

    var cursor: UnsafeMutablePointer<addrinfo>? = first
    while let current = cursor {
      if let address = resolvedAddress(current.pointee), address.isPrivate {
        return true
      }
      cursor = current.pointee.ai_next
    }
    return false
  }

  public static func isPrivateIPAddress(_ value: String) -> Bool {
    parsedAddress(value)?.isPrivate ?? false
  }

  private enum ParsedAddress {
    case ipv4(UInt32)
    case ipv6([UInt8])

    var isPrivate: Bool {
      switch self {
      case .ipv4(let address):
        return (address & 0xff00_0000) == 0x7f00_0000
          || (address & 0xffff_0000) == 0xc0a8_0000
          || (address & 0xfff0_0000) == 0xac10_0000
          || (address & 0xff00_0000) == 0x0a00_0000
      case .ipv6(let bytes):
        let loopback = bytes.dropLast().allSatisfy { $0 == 0 } && bytes.last == 1
        let linkLocal = bytes.count == 16 && bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80
        return loopback || linkLocal
      }
    }
  }

  private static func parsedAddress(_ value: String) -> ParsedAddress? {
    var ipv4 = in_addr()
    if value.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 {
      return .ipv4(UInt32(bigEndian: ipv4.s_addr))
    }
    var ipv6 = in6_addr()
    if value.withCString({ inet_pton(AF_INET6, $0, &ipv6) }) == 1 {
      return withUnsafeBytes(of: &ipv6) { .ipv6(Array($0)) }
    }
    return nil
  }

  private static func resolvedAddress(_ info: addrinfo) -> ParsedAddress? {
    guard let pointer = info.ai_addr else { return nil }
    switch Int32(info.ai_family) {
    case AF_INET:
      let address = pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
        $0.pointee.sin_addr.s_addr
      }
      return .ipv4(UInt32(bigEndian: address))
    case AF_INET6:
      var address = pointer.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
        $0.pointee.sin6_addr
      }
      return withUnsafeBytes(of: &address) { .ipv6(Array($0)) }
    default:
      return nil
    }
  }
}

public enum FletUserFonts {
  /// Mirrors `parseFonts()` from the Flet client. MessagePack already decodes
  /// JSON object values into RufletValue, so only string-valued font entries
  /// participate in the resulting family-to-source map.
  public static func parse(_ value: RufletValue?) -> [String: String]? {
    guard let entries = value?.mapValue else { return nil }
    return entries.reduce(into: [:]) { result, entry in
      if let source = entry.value.stringValue {
        result[entry.key] = source
      }
    }
  }
}
