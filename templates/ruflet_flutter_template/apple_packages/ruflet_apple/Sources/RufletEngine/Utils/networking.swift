import Darwin
import Foundation

public enum RufletNetworkingError: Error, Equatable {
  case cannotResolveHost(String)
  case invalidIPAddress(String)
}

/// Resolves a host and reports whether its first address is private, loopback,
/// or IPv6 link-local, matching the pinned Flet networking helper.
public func isPrivateHost(_ host: String) async throws -> Bool {
  let addresses = try resolvedSocketAddresses(host)
  guard let address = addresses.first else {
    throw RufletNetworkingError.cannotResolveHost(host)
  }
  return isPrivateSocketAddress(address)
}

/// Converts an IPv4 address to its unsigned big-endian integer representation.
public func ipToInt(_ ip: String) throws -> UInt32 {
  var address = in_addr()
  guard inet_pton(AF_INET, ip, &address) == 1 else {
    throw RufletNetworkingError.invalidIPAddress(ip)
  }
  return UInt32(bigEndian: address.s_addr)
}

private func resolvedSocketAddresses(_ host: String) throws -> [sockaddr_storage] {
  var hints = addrinfo(
    ai_flags: AI_ADDRCONFIG,
    ai_family: AF_UNSPEC,
    ai_socktype: SOCK_STREAM,
    ai_protocol: IPPROTO_TCP,
    ai_addrlen: 0,
    ai_canonname: nil,
    ai_addr: nil,
    ai_next: nil)
  var result: UnsafeMutablePointer<addrinfo>?
  let status = getaddrinfo(host, nil, &hints, &result)
  guard status == 0, let first = result else {
    throw RufletNetworkingError.cannotResolveHost(host)
  }
  defer { freeaddrinfo(first) }

  var addresses: [sockaddr_storage] = []
  var cursor: UnsafeMutablePointer<addrinfo>? = first
  while let info = cursor?.pointee {
    if let source = info.ai_addr {
      var storage = sockaddr_storage()
      memcpy(&storage, source, min(Int(info.ai_addrlen), MemoryLayout.size(ofValue: storage)))
      addresses.append(storage)
    }
    cursor = info.ai_next
  }
  return addresses
}

private func isPrivateSocketAddress(_ storage: sockaddr_storage) -> Bool {
  if Int32(storage.ss_family) == AF_INET {
    var address = storage
    let value: UInt32 = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
        UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
      }
    }
    let ranges: [(network: UInt32, mask: UInt32)] = [
      (0x7F00_0000, 0xFF00_0000),
      (0xC0A8_0000, 0xFFFF_0000),
      (0xAC10_0000, 0xFFF0_0000),
      (0x0A00_0000, 0xFF00_0000),
    ]
    return ranges.contains { value & $0.mask == $0.network }
  }

  guard Int32(storage.ss_family) == AF_INET6 else { return false }
  var address = storage
  return withUnsafePointer(to: &address) {
    $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { pointer in
      let bytes = withUnsafeBytes(of: pointer.pointee.sin6_addr) { Array($0) }
      let loopback = bytes.dropLast().allSatisfy { $0 == 0 } && bytes.last == 1
      let linkLocal = bytes.count == 16 && bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80
      return loopback || linkLocal
    }
  }
}
