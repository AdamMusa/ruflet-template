import Foundation

/// MessagePack reader/writer for the Ruflet wire format.
///
/// Deliberately a mirror of `Ruflet::WireCodec` rather than a general-purpose
/// implementation: the two must agree byte for byte, including the choice to
/// always emit ext8/16/32 (never fixext) for the three temporal extension
/// types, and to stringify every map key.
public enum MessagePack {
  public enum DecodingError: Error, Equatable {
    case unexpectedEndOfInput
    case unsupportedMarker(UInt8)
    case invalidUTF8
  }

  // MARK: - Encoding

  public static func encode(_ value: RufletValue) -> [UInt8] {
    var out: [UInt8] = []
    out.reserveCapacity(64)
    write(value, into: &out)
    return out
  }

  public static func encodeData(_ value: RufletValue) -> Data {
    Data(encode(value))
  }

  private static func write(_ value: RufletValue, into out: inout [UInt8]) {
    switch value {
    case .null:
      out.append(0xc0)
    case .bool(let flag):
      out.append(flag ? 0xc3 : 0xc2)
    case .int(let number):
      writeInteger(number, into: &out)
    case .controlRef(let id):
      writeInteger(Int64(id), into: &out)
    case .double(let number):
      out.append(0xcb)
      appendBigEndian(number.bitPattern, into: &out)
    case .string(let text):
      writeString(text, into: &out)
    case .binary(let bytes):
      writeBinary(bytes, into: &out)
    case .array(let items):
      writeArrayHeader(items.count, into: &out)
      for item in items { write(item, into: &out) }
    case .map(let entries):
      writeMapHeader(entries.count, into: &out)
      // Sorted so identical maps encode identically; the Ruby side does not
      // depend on key order, but reproducible bytes make tests meaningful.
      for key in entries.keys.sorted() {
        writeString(key, into: &out)
        write(entries[key]!, into: &out)
      }
    case .extended(let type, let text):
      writeExtension(type: type, payload: Array(text.utf8), into: &out)
    }
  }

  private static func writeInteger(_ value: Int64, into out: inout [UInt8]) {
    if value >= 0 {
      if value <= 0x7f {
        out.append(UInt8(value))
      } else if value <= 0xff {
        out.append(0xcc)
        out.append(UInt8(value))
      } else if value <= 0xffff {
        out.append(0xcd)
        appendBigEndian(UInt16(value), into: &out)
      } else if value <= 0xffff_ffff {
        out.append(0xce)
        appendBigEndian(UInt32(value), into: &out)
      } else {
        out.append(0xcf)
        appendBigEndian(UInt64(value), into: &out)
      }
    } else {
      if value >= -32 {
        out.append(UInt8(bitPattern: Int8(value)))
      } else if value >= -128 {
        out.append(0xd0)
        out.append(UInt8(bitPattern: Int8(value)))
      } else if value >= -32_768 {
        out.append(0xd1)
        appendBigEndian(UInt16(bitPattern: Int16(value)), into: &out)
      } else if value >= -2_147_483_648 {
        out.append(0xd2)
        appendBigEndian(UInt32(bitPattern: Int32(value)), into: &out)
      } else {
        out.append(0xd3)
        appendBigEndian(UInt64(bitPattern: value), into: &out)
      }
    }
  }

  private static func writeString(_ text: String, into out: inout [UInt8]) {
    let bytes = Array(text.utf8)
    let count = bytes.count
    if count <= 31 {
      out.append(0xa0 | UInt8(count))
    } else if count <= 0xff {
      out.append(0xd9)
      out.append(UInt8(count))
    } else if count <= 0xffff {
      out.append(0xda)
      appendBigEndian(UInt16(count), into: &out)
    } else {
      out.append(0xdb)
      appendBigEndian(UInt32(count), into: &out)
    }
    out.append(contentsOf: bytes)
  }

  private static func writeBinary(_ bytes: [UInt8], into out: inout [UInt8]) {
    let count = bytes.count
    if count <= 0xff {
      out.append(0xc4)
      out.append(UInt8(count))
    } else if count <= 0xffff {
      out.append(0xc5)
      appendBigEndian(UInt16(count), into: &out)
    } else {
      out.append(0xc6)
      appendBigEndian(UInt32(count), into: &out)
    }
    out.append(contentsOf: bytes)
  }

  private static func writeArrayHeader(_ count: Int, into out: inout [UInt8]) {
    if count <= 15 {
      out.append(0x90 | UInt8(count))
    } else if count <= 0xffff {
      out.append(0xdc)
      appendBigEndian(UInt16(count), into: &out)
    } else {
      out.append(0xdd)
      appendBigEndian(UInt32(count), into: &out)
    }
  }

  private static func writeMapHeader(_ count: Int, into out: inout [UInt8]) {
    if count <= 15 {
      out.append(0x80 | UInt8(count))
    } else if count <= 0xffff {
      out.append(0xde)
      appendBigEndian(UInt16(count), into: &out)
    } else {
      out.append(0xdf)
      appendBigEndian(UInt32(count), into: &out)
    }
  }

  private static func writeExtension(type: Int8, payload: [UInt8], into out: inout [UInt8]) {
    let count = payload.count
    if count <= 0xff {
      out.append(0xc7)
      out.append(UInt8(count))
    } else if count <= 0xffff {
      out.append(0xc8)
      appendBigEndian(UInt16(count), into: &out)
    } else {
      out.append(0xc9)
      appendBigEndian(UInt32(count), into: &out)
    }
    out.append(UInt8(bitPattern: type))
    out.append(contentsOf: payload)
  }

  private static func appendBigEndian<T: FixedWidthInteger>(_ value: T, into out: inout [UInt8]) {
    let big = value.bigEndian
    withUnsafeBytes(of: big) { out.append(contentsOf: $0) }
  }

  // MARK: - Decoding

  public static func decode(_ data: Data) throws -> RufletValue {
    try decode(Array(data))
  }

  public static func decode(_ bytes: [UInt8]) throws -> RufletValue {
    var reader = Reader(bytes)
    return try read(&reader)
  }

  private struct Reader {
    let bytes: [UInt8]
    var offset: Int = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    mutating func readByte() throws -> UInt8 {
      guard offset < bytes.count else { throw DecodingError.unexpectedEndOfInput }
      defer { offset += 1 }
      return bytes[offset]
    }

    mutating func readBytes(_ count: Int) throws -> [UInt8] {
      guard count >= 0, offset + count <= bytes.count else {
        throw DecodingError.unexpectedEndOfInput
      }
      defer { offset += count }
      return Array(bytes[offset..<(offset + count)])
    }

    mutating func readBigEndian<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
      let raw = try readBytes(MemoryLayout<T>.size)
      return raw.reduce(T(0)) { ($0 << 8) | T($1) }
    }
  }

  private static func read(_ reader: inout Reader) throws -> RufletValue {
    let marker = try reader.readByte()

    if marker <= 0x7f { return .int(Int64(marker)) }
    if marker >= 0xe0 { return .int(Int64(Int8(bitPattern: marker))) }

    switch marker {
    case 0xc0: return .null
    case 0xc2: return .bool(false)
    case 0xc3: return .bool(true)

    case 0xcc: return .int(Int64(try reader.readByte()))
    case 0xcd: return .int(Int64(try reader.readBigEndian(UInt16.self)))
    case 0xce: return .int(Int64(try reader.readBigEndian(UInt32.self)))
    case 0xcf: return .int(Int64(bitPattern: try reader.readBigEndian(UInt64.self)))

    case 0xd0: return .int(Int64(Int8(bitPattern: try reader.readByte())))
    case 0xd1: return .int(Int64(Int16(bitPattern: try reader.readBigEndian(UInt16.self))))
    case 0xd2: return .int(Int64(Int32(bitPattern: try reader.readBigEndian(UInt32.self))))
    case 0xd3: return .int(Int64(bitPattern: try reader.readBigEndian(UInt64.self)))

    case 0xca: return .double(Double(Float(bitPattern: try reader.readBigEndian(UInt32.self))))
    case 0xcb: return .double(Double(bitPattern: try reader.readBigEndian(UInt64.self)))

    case 0xd9: return .string(try readString(&reader, count: Int(try reader.readByte())))
    case 0xda: return .string(try readString(&reader, count: Int(try reader.readBigEndian(UInt16.self))))
    case 0xdb: return .string(try readString(&reader, count: Int(try reader.readBigEndian(UInt32.self))))

    case 0xc4: return .binary(try reader.readBytes(Int(try reader.readByte())))
    case 0xc5: return .binary(try reader.readBytes(Int(try reader.readBigEndian(UInt16.self))))
    case 0xc6: return .binary(try reader.readBytes(Int(try reader.readBigEndian(UInt32.self))))

    case 0xdc: return try readArray(&reader, count: Int(try reader.readBigEndian(UInt16.self)))
    case 0xdd: return try readArray(&reader, count: Int(try reader.readBigEndian(UInt32.self)))
    case 0xde: return try readMap(&reader, count: Int(try reader.readBigEndian(UInt16.self)))
    case 0xdf: return try readMap(&reader, count: Int(try reader.readBigEndian(UInt32.self)))

    case 0xd4: return try readExtension(&reader, count: 1)
    case 0xd5: return try readExtension(&reader, count: 2)
    case 0xd6: return try readExtension(&reader, count: 4)
    case 0xd7: return try readExtension(&reader, count: 8)
    case 0xd8: return try readExtension(&reader, count: 16)
    case 0xc7: return try readExtension(&reader, count: Int(try reader.readByte()))
    case 0xc8: return try readExtension(&reader, count: Int(try reader.readBigEndian(UInt16.self)))
    case 0xc9: return try readExtension(&reader, count: Int(try reader.readBigEndian(UInt32.self)))

    default:
      if marker & 0xf0 == 0x90 { return try readArray(&reader, count: Int(marker & 0x0f)) }
      if marker & 0xf0 == 0x80 { return try readMap(&reader, count: Int(marker & 0x0f)) }
      if marker & 0xe0 == 0xa0 { return .string(try readString(&reader, count: Int(marker & 0x1f))) }
      throw DecodingError.unsupportedMarker(marker)
    }
  }

  private static func readString(_ reader: inout Reader, count: Int) throws -> String {
    let raw = try reader.readBytes(count)
    guard let text = String(bytes: raw, encoding: .utf8) else {
      throw DecodingError.invalidUTF8
    }
    return text
  }

  private static func readArray(_ reader: inout Reader, count: Int) throws -> RufletValue {
    var items: [RufletValue] = []
    items.reserveCapacity(count)
    for _ in 0..<count { items.append(try read(&reader)) }
    return .array(items)
  }

  private static func readMap(_ reader: inout Reader, count: Int) throws -> RufletValue {
    var entries: [String: RufletValue] = [:]
    entries.reserveCapacity(count)
    for _ in 0..<count {
      // Ruby's reader coerces every key with `to_s`; do the same so a numeric
      // key on the wire still lands in a string-keyed prop map.
      let key = try read(&reader).stringValue ?? ""
      entries[key] = try read(&reader)
    }
    return .map(entries)
  }

  private static func readExtension(_ reader: inout Reader, count: Int) throws -> RufletValue {
    let type = Int8(bitPattern: try reader.readByte())
    let payload = try reader.readBytes(count)
    let text = String(bytes: payload, encoding: .utf8) ?? ""
    return .extended(type: type, string: text)
  }
}
