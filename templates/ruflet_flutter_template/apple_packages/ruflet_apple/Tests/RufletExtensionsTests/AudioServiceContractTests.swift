import RufletAudio
import RufletEngine
import RufletProtocol
import XCTest

@MainActor
final class AudioServiceContractTests: XCTestCase {
  func testCommandsLoadAndReloadTheDeclarativeSourceAfterRelease() async throws {
    let backend = AudioServiceTestBackend()
    let control = RufletControl(
      id: 1,
      type: "Audio",
      properties: [
        "src": .binary(Self.waveData()),
        "autoplay": .bool(false),
        "release_mode": .string("stop"),
      ],
      backend: backend)
    let service = AudioService(control: control)
    service.initialize()
    defer { service.dispose() }

    let initialDuration = try await control.invokeMethod("get_duration", arguments: .null)
    XCTAssertGreaterThan(initialDuration.integer ?? 0, 0)

    _ = try await control.invokeMethod("release", arguments: .null)
    let reloadedDuration = try await control.invokeMethod("get_duration", arguments: .null)
    XCTAssertEqual(reloadedDuration, initialDuration)
  }

  private static func waveData() -> Data {
    let sampleRate: UInt32 = 8_000
    let sampleCount: UInt32 = 800
    let dataSize = sampleCount * 2
    var data = Data()
    data.append(contentsOf: "RIFF".utf8)
    data.appendLittleEndian(UInt32(36) + dataSize)
    data.append(contentsOf: "WAVEfmt ".utf8)
    data.appendLittleEndian(UInt32(16))
    data.appendLittleEndian(UInt16(1))
    data.appendLittleEndian(UInt16(1))
    data.appendLittleEndian(sampleRate)
    data.appendLittleEndian(sampleRate * 2)
    data.appendLittleEndian(UInt16(2))
    data.appendLittleEndian(UInt16(16))
    data.append(contentsOf: "data".utf8)
    data.appendLittleEndian(dataSize)
    data.append(Data(repeating: 0, count: Int(dataSize)))
    return data
  }
}

private extension Data {
  mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
    var encoded = value.littleEndian
    Swift.withUnsafeBytes(of: &encoded) { append(contentsOf: $0) }
  }
}

@MainActor
private final class AudioServiceTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
