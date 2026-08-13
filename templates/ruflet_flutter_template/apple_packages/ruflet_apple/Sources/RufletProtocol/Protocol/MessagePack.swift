import Foundation

/// Flet-compatible MessagePack encoder and streaming decoder.
public enum RufletMessagePack {
  public static func encode(_ value: RufletValue) -> Data {
    var bytes: [UInt8] = []
    write(value, to: &bytes)
    return Data(bytes)
  }

  public static func decode(_ data: Data) throws -> RufletValue {
    var reader = Reader(data: data)
    return try reader.readValue()
  }

  public static func temporalDate(_ date: Date) -> RufletValue {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let text = formatter.string(from: date).replacingOccurrences(of: "Z", with: "+00:00")
    return .extensionValue(type: 1, payload: Data(text.utf8))
  }

  public static func temporalTime(hour: Int, minute: Int) -> RufletValue {
    .extensionValue(type: 2, payload: Data("\(hour):\(minute)".utf8))
  }

  public static func temporalDuration(microseconds: Int64) -> RufletValue {
    .extensionValue(type: 3, payload: Data(String(microseconds).utf8))
  }

  private static func write(_ value: RufletValue, to bytes: inout [UInt8]) {
    switch value {
    case .null: bytes.append(0xc0)
    case .bool(let value): bytes.append(value ? 0xc3 : 0xc2)
    case .int(let value): writeInteger(value, to: &bytes)
    case .double(let value):
      bytes.append(0xcb)
      append(value.bitPattern, to: &bytes)
    case .string(let value): writeString(value, to: &bytes)
    case .binary(let data): writeBinary(data, to: &bytes)
    case .array(let values):
      writeArrayHeader(values.count, to: &bytes)
      values.forEach { write($0, to: &bytes) }
    case .map(let values):
      writeMapHeader(values.count, to: &bytes)
      for (key, value) in values {
        writeString(key, to: &bytes)
        write(value, to: &bytes)
      }
    case .keyedMap(let values):
      writeMapHeader(values.count, to: &bytes)
      for (key, value) in values {
        write(key.value, to: &bytes)
        write(value, to: &bytes)
      }
    case .extensionValue(let type, let payload):
      let count = payload.count
      if count <= 0xff { bytes += [0xc7, UInt8(count)] }
      else if count <= 0xffff { bytes.append(0xc8); append(UInt16(count), to: &bytes) }
      else { bytes.append(0xc9); append(UInt32(count), to: &bytes) }
      bytes.append(UInt8(bitPattern: type))
      bytes += payload
    }
  }

  private static func writeInteger(_ value: Int64, to bytes: inout [UInt8]) {
    switch value {
    case 0...127: bytes.append(UInt8(value))
    case -32 ... -1: bytes.append(UInt8(bitPattern: Int8(value)))
    case 0...255: bytes += [0xcc, UInt8(value)]
    case 0...65_535: bytes.append(0xcd); append(UInt16(value), to: &bytes)
    case 0...4_294_967_295: bytes.append(0xce); append(UInt32(value), to: &bytes)
    case 0...Int64.max: bytes.append(0xcf); append(UInt64(value), to: &bytes)
    case -128 ... -33: bytes += [0xd0, UInt8(bitPattern: Int8(value))]
    case -32_768 ... -129: bytes.append(0xd1); append(UInt16(bitPattern: Int16(value)), to: &bytes)
    case -2_147_483_648 ... -32_769:
      bytes.append(0xd2); append(UInt32(bitPattern: Int32(value)), to: &bytes)
    default: bytes.append(0xd3); append(UInt64(bitPattern: value), to: &bytes)
    }
  }

  private static func writeString(_ value: String, to bytes: inout [UInt8]) {
    let data = Data(value.utf8)
    if data.count <= 31 { bytes.append(0xa0 | UInt8(data.count)) }
    else if data.count <= 0xff { bytes += [0xd9, UInt8(data.count)] }
    else if data.count <= 0xffff { bytes.append(0xda); append(UInt16(data.count), to: &bytes) }
    else { bytes.append(0xdb); append(UInt32(data.count), to: &bytes) }
    bytes += data
  }

  private static func writeBinary(_ data: Data, to bytes: inout [UInt8]) {
    if data.count <= 0xff { bytes += [0xc4, UInt8(data.count)] }
    else if data.count <= 0xffff { bytes.append(0xc5); append(UInt16(data.count), to: &bytes) }
    else { bytes.append(0xc6); append(UInt32(data.count), to: &bytes) }
    bytes += data
  }

  private static func writeArrayHeader(_ count: Int, to bytes: inout [UInt8]) {
    if count <= 15 { bytes.append(0x90 | UInt8(count)) }
    else if count <= 0xffff { bytes.append(0xdc); append(UInt16(count), to: &bytes) }
    else { bytes.append(0xdd); append(UInt32(count), to: &bytes) }
  }

  private static func writeMapHeader(_ count: Int, to bytes: inout [UInt8]) {
    if count <= 15 { bytes.append(0x80 | UInt8(count)) }
    else if count <= 0xffff { bytes.append(0xde); append(UInt16(count), to: &bytes) }
    else { bytes.append(0xdf); append(UInt32(count), to: &bytes) }
  }

  private static func append<T: FixedWidthInteger>(_ value: T, to bytes: inout [UInt8]) {
    var value = value.bigEndian
    withUnsafeBytes(of: &value) { bytes += $0 }
  }

  fileprivate struct Reader {
    let data: Data
    var offset = 0

    mutating func readValue() throws -> RufletValue {
      let marker = try byte()
      if marker <= 0x7f { return .int(Int64(marker)) }
      if marker >= 0xe0 { return .int(Int64(Int8(bitPattern: marker))) }
      if marker & 0xe0 == 0xa0 { return .string(try string(Int(marker & 0x1f))) }
      if marker & 0xf0 == 0x90 { return try array(Int(marker & 0x0f)) }
      if marker & 0xf0 == 0x80 { return try map(Int(marker & 0x0f)) }

      switch marker {
      case 0xc0: return .null
      case 0xc2: return .bool(false)
      case 0xc3: return .bool(true)
      case 0xcc: return .int(Int64(try byte()))
      case 0xcd: return .int(Int64(try integer(UInt16.self)))
      case 0xce: return .int(Int64(try integer(UInt32.self)))
      case 0xcf:
        let value = try integer(UInt64.self)
        guard value <= UInt64(Int64.max) else { throw RufletProtocolError.invalidMessage }
        return .int(Int64(value))
      case 0xd0: return .int(Int64(Int8(bitPattern: try byte())))
      case 0xd1: return .int(Int64(Int16(bitPattern: try integer(UInt16.self))))
      case 0xd2: return .int(Int64(Int32(bitPattern: try integer(UInt32.self))))
      case 0xd3: return .int(Int64(bitPattern: try integer(UInt64.self)))
      case 0xca: return .double(Double(Float(bitPattern: try integer(UInt32.self))))
      case 0xcb: return .double(Double(bitPattern: try integer(UInt64.self)))
      case 0xd9: return .string(try string(Int(try byte())))
      case 0xda: return .string(try string(Int(try integer(UInt16.self))))
      case 0xdb: return .string(try string(Int(try integer(UInt32.self))))
      case 0xc4: return .binary(try bytes(Int(try byte())))
      case 0xc5: return .binary(try bytes(Int(try integer(UInt16.self))))
      case 0xc6: return .binary(try bytes(Int(try integer(UInt32.self))))
      case 0xdc: return try array(Int(try integer(UInt16.self)))
      case 0xdd: return try array(Int(try integer(UInt32.self)))
      case 0xde: return try map(Int(try integer(UInt16.self)))
      case 0xdf: return try map(Int(try integer(UInt32.self)))
      case 0xd4: return try extensionValue(1)
      case 0xd5: return try extensionValue(2)
      case 0xd6: return try extensionValue(4)
      case 0xd7: return try extensionValue(8)
      case 0xd8: return try extensionValue(16)
      case 0xc7: return try extensionValue(Int(try byte()))
      case 0xc8: return try extensionValue(Int(try integer(UInt16.self)))
      case 0xc9: return try extensionValue(Int(try integer(UInt32.self)))
      default: throw RufletProtocolError.unsupportedMessagePackMarker(marker)
      }
    }

    mutating func byte() throws -> UInt8 {
      guard offset < data.count else { throw RufletProtocolError.truncatedMessagePack }
      defer { offset += 1 }
      return data[offset]
    }

    mutating func bytes(_ count: Int) throws -> Data {
      guard count >= 0, offset + count <= data.count else {
        throw RufletProtocolError.truncatedMessagePack
      }
      defer { offset += count }
      return data[offset ..< offset + count]
    }

    mutating func integer<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
      let data = try bytes(MemoryLayout<T>.size)
      return data.reduce(T.zero) { ($0 << 8) | T($1) }
    }

    mutating func string(_ count: Int) throws -> String {
      guard let string = String(data: try bytes(count), encoding: .utf8) else {
        throw RufletProtocolError.invalidUTF8
      }
      return string
    }

    mutating func array(_ count: Int) throws -> RufletValue {
      var result: [RufletValue] = []
      result.reserveCapacity(count)
      for _ in 0 ..< count { result.append(try readValue()) }
      return .array(result)
    }

    mutating func map(_ count: Int) throws -> RufletValue {
      var result: [RufletMapKey: RufletValue] = [:]
      var hasIntegerKey = false
      for _ in 0 ..< count {
        let key: RufletMapKey
        switch try readValue() {
        case .string(let value):
          key = .string(value)
        case .int(let value):
          key = .int(value)
          hasIntegerKey = true
        default:
          throw RufletProtocolError.invalidMessage
        }
        result[key] = try readValue()
      }
      if hasIntegerKey { return .keyedMap(result) }
      return .map(Dictionary(uniqueKeysWithValues: result.map { entry in
        guard case .string(let key) = entry.key else {
          preconditionFailure("String-only MessagePack map contained a non-string key")
        }
        return (key, entry.value)
      }))
    }

    mutating func extensionValue(_ count: Int) throws -> RufletValue {
      .extensionValue(type: Int8(bitPattern: try byte()), payload: try bytes(count))
    }
  }
}

public struct RufletStreamingMessagePackDecoder {
  private var buffer = Data()

  public init() {}

  public mutating func append(_ data: Data) { buffer.append(data) }

  public mutating func decodeAvailable() throws -> [RufletValue] {
    var reader = RufletMessagePack.Reader(data: buffer)
    var values: [RufletValue] = []
    while reader.offset < buffer.count {
      let start = reader.offset
      do { values.append(try reader.readValue()) }
      catch RufletProtocolError.truncatedMessagePack {
        reader.offset = start
        break
      }
    }
    buffer = Data(buffer.dropFirst(reader.offset))
    return values
  }
}
