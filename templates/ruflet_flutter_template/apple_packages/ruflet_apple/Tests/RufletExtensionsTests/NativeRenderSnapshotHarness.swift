#if os(macOS)
  import AppKit
  import RufletCharts
  import RufletProtocol
  import RufletSpinKit
  import SwiftUI
  import XCTest

  @testable import RufletEngine

  /// Rasterizes the native renderer from a captured `register_client` response so
  /// its output can be diffed against the Flutter reference rendering of the same
  /// session. Enabled only when `RUFLET_RENDER_SNAPSHOT` names an output path.
  @MainActor
  final class NativeRenderSnapshotHarness: XCTestCase {
    func testRenderCapturedSession() throws {
      let environment = ProcessInfo.processInfo.environment
      guard let output = environment["RUFLET_RENDER_SNAPSHOT"],
        let payload = environment["RUFLET_RENDER_PAYLOAD"]
      else { throw XCTSkip("RUFLET_RENDER_SNAPSHOT not set") }

      let width = Double(environment["RUFLET_RENDER_WIDTH"] ?? "") ?? 800
      let height = Double(environment["RUFLET_RENDER_HEIGHT"] ?? "") ?? 600
      let messages = try Self.decodeMessages(path: payload)

      let backend = RufletBackend(
        pageURL: URL(string: "http://localhost:8552")!,
        assetsDirectory: "",
        extensions: [RufletSpinKitExtension(), RufletChartsExtension()],
        channelFactory: { _, _, _ in throw RenderHarnessError.offline })
      _ = backend.page.update(
        [
          "width": .double(width),
          "height": .double(height),
          "platform_brightness": .string("dark"),
        ], notify: false)
      // Replaying the captured `patch_control` stream after the initial
      // register response reconstructs any screen the app reached at runtime,
      // not just its first one.
      for message in messages {
        let started = ProcessInfo.processInfo.systemUptime
        switch message.action {
        case .registerClient:
          let body = try RufletRegisterClientResponseBody(value: message.payload)
          _ = backend.page.update(body.pagePatch, notify: true)
        case .patchControl:
          let request = try RufletPatchControlRequestBody(value: message.payload)
          let target = try XCTUnwrap(
            Self.control(id: request.id, in: backend.page),
            "patch targets unknown control \(request.id)")
          try target.applyPatch(request.patch)
        default:
          continue
        }
        print(
          String(
            format: "APPLY %@ %.1f ms", String(describing: message.action),
            (ProcessInfo.processInfo.systemUptime - started) * 1000))
      }

      let root = RufletHeroScope {
        ControlWidget(control: backend.page)
      }
      .environmentObject(backend.extensionRegistry)
      .environmentObject(backend)
      .frame(width: width, height: height)

      let size = CGSize(width: width, height: height)
      let hosting = NSHostingView(rootView: root)
      hosting.appearance = NSAppearance(named: .darkAqua)
      hosting.frame = CGRect(origin: .zero, size: size)
      let window = NSWindow(
        contentRect: hosting.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false)
      window.contentView = hosting
      window.makeKeyAndOrderFront(nil)

      // Time the layout/display work itself. The RunLoop turns below are the
      // harness idling to let SwiftUI deliver async updates; folding them into
      // the measurement makes a fast renderer look slow.
      var layoutTotal: TimeInterval = 0
      for pass in 0..<10 {
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        let started = ProcessInfo.processInfo.systemUptime
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        layoutTotal += elapsed
        print(String(format: "LAYOUTPASS %d %.1f ms", pass, elapsed * 1000))
      }
      print(String(format: "LAYOUTTOTAL %.1f ms", layoutTotal * 1000))
      print("BODYEVALS \(RufletRenderCounters.bodyEvaluations) for \(Self.controlCount(backend.page)) controls")

      let rep = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
      hosting.cacheDisplay(in: hosting.bounds, to: rep)
      let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
      try data.write(to: URL(fileURLWithPath: output))
    }

    /// One `[RUFLET_PROTOCOL]` `hex=` field per line, in capture order.
    private static func decodeMessages(path: String) throws -> [RufletMessage] {
      try String(contentsOfFile: path, encoding: .utf8)
        .split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
        .map { line in
          var bytes = [UInt8]()
          bytes.reserveCapacity(line.count / 2)
          var index = line.startIndex
          while index < line.endIndex {
            let next = line.index(index, offsetBy: 2)
            guard let byte = UInt8(line[index..<next], radix: 16) else {
              throw RenderHarnessError.malformedPayload
            }
            bytes.append(byte)
            index = next
          }
          guard let list = try RufletMessagePack.decode(Data(bytes)).array else {
            throw RenderHarnessError.malformedPayload
          }
          return try RufletMessage(list: list)
        }
    }

    /// `RufletBackend` keeps its control index private, so resolve the patch
    /// target by walking the published property graph the same way the
    /// semantics debugger does.
    private static func controlCount(_ root: RufletControl) -> Int {
      var total = 1
      for property in root.properties.keys {
        for child in root.children(property, visibleOnly: false) {
          total += controlCount(child)
        }
      }
      return total
    }

    private static func control(id: Int, in root: RufletControl) -> RufletControl? {
      if root.id == id { return root }
      for property in root.properties.keys {
        for child in root.children(property, visibleOnly: false) {
          if let match = control(id: id, in: child) { return match }
        }
      }
      return nil
    }
  }

  private enum RenderHarnessError: Error {
    case offline
    case malformedPayload
  }
#endif
