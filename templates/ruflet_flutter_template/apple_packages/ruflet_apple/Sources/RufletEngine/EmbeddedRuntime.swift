import Foundation

/// Boots the embedded mruby VM and reports the port its server bound.
///
/// This is the same contract the Flutter bridge uses — `ruflet_vm_start` from
/// `ruby_runtime/desktop/ruflet_vm_host.h`, with the runtime publishing its
/// port into `RUFLET_RUNTIME_PORT_FILE` — so the native side still owns VM
/// startup and nothing about that moves into the renderer.
///
/// The four entry points are resolved with `dlsym` rather than linked, because
/// the VM ships as an XCFramework on iOS and a static archive on macOS. An app
/// links whichever it needs; this package stays a pure Swift package that
/// builds anywhere.
public final class EmbeddedRuntime {
  public struct Configuration {
    /// Directory added to `$LOAD_PATH`, holding the app's Ruby sources.
    public var projectRoot: String
    /// The `.rb` or `.mrb` file to run, normally `main.rb`.
    public var entrypoint: String
    public var loadPaths: [String]
    public var environment: [String: String]
    /// Scratch directory for the port/error/stop files. Defaults to a
    /// `ruflet-runtime` folder under the app's temporary directory, because the
    /// bundle itself is read-only.
    public var scratchDirectory: String

    public init(
      projectRoot: String,
      entrypoint: String? = nil,
      loadPaths: [String]? = nil,
      environment: [String: String] = [:],
      scratchDirectory: String? = nil
    ) {
      self.projectRoot = projectRoot
      self.entrypoint = entrypoint ?? (projectRoot as NSString).appendingPathComponent("main.rb")
      self.loadPaths = loadPaths ?? [projectRoot]
      self.environment = environment
      self.scratchDirectory =
        scratchDirectory
        ?? (NSTemporaryDirectory() as NSString).appendingPathComponent("ruflet-runtime")
    }

    var portFile: String { (scratchDirectory as NSString).appendingPathComponent("server.port") }
    var errorFile: String { (scratchDirectory as NSString).appendingPathComponent("server.error") }
    var stopFile: String { (scratchDirectory as NSString).appendingPathComponent("server.stop") }
  }

  public enum StartupError: LocalizedError {
    case vmSymbolsMissing
    case rejectedEntrypoint(Int32)
    case runtimeReported(String)
    case portNotPublished(TimeInterval)

    public var errorDescription: String? {
      switch self {
      case .vmSymbolsMissing:
        return """
          The embedded Ruby VM is not linked into this process. Link RufletVM.xcframework \
          (iOS) or libruflet_vm.a (macOS) from ruby_runtime/, or point the engine at a \
          running server with RufletAppView(serverURL:).
          """
      case .rejectedEntrypoint(let status):
        return
          "The VM rejected the entrypoint (status \(status)); it must be a .rb or .mrb file inside the project root."
      case .runtimeReported(let message):
        return message
      case .portNotPublished(let seconds):
        return "The embedded Ruflet server did not publish a port within \(Int(seconds))s."
      }
    }
  }

  private typealias StartFunction = @convention(c) (
    UnsafePointer<CChar>?, UnsafePointer<CChar>?,
    UnsafePointer<UnsafePointer<CChar>?>?, Int,
    UnsafePointer<UnsafePointer<CChar>?>?, UnsafePointer<UnsafePointer<CChar>?>?, Int,
    UnsafePointer<CChar>?, UnsafePointer<CChar>?
  ) -> Int32
  private typealias IsRunningFunction = @convention(c) () -> Int32
  private typealias StopFunction = @convention(c) () -> Void

  public let configuration: Configuration

  public init(configuration: Configuration) {
    self.configuration = configuration
  }

  /// True when the VM binary is present in this process.
  public static var isAvailable: Bool {
    dlsym(UnsafeMutableRawPointer(bitPattern: -2), "ruflet_vm_start") != nil
  }

  public static var isRunning: Bool {
    guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "ruflet_vm_is_running") else {
      return false
    }
    return unsafeBitCast(symbol, to: IsRunningFunction.self)() != 0
  }

  public static func stop() {
    guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "ruflet_vm_stop") else {
      return
    }
    unsafeBitCast(symbol, to: StopFunction.self)()
  }

  /// Starts the VM (if the platform layer has not already) and waits for the
  /// runtime to publish its port.
  ///
  /// Safe to call when the app's `+load` bridge already autostarted the VM:
  /// `ruflet_vm_start` sees a running VM and returns success without adopting
  /// the arguments, and this then reads the port that startup published.
  public func start(timeout: TimeInterval = 30) throws -> Int {
    guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "ruflet_vm_start") else {
      throw StartupError.vmSymbolsMissing
    }
    let startVM = unsafeBitCast(symbol, to: StartFunction.self)

    // A platform bridge that autostarted the VM from `+load` has already
    // published its port. Starting again is a no-op inside the VM host, so the
    // only thing left to do is read what it published — and emphatically not
    // to clear those files first, which would leave nothing to read and no
    // second boot to rewrite them.
    if Self.isRunning {
      return try waitForPort(timeout: timeout)
    }

    let files = FileManager.default
    try? files.createDirectory(
      atPath: configuration.scratchDirectory, withIntermediateDirectories: true)
    for stale in [configuration.portFile, configuration.errorFile, configuration.stopFile] {
      try? files.removeItem(atPath: stale)
    }

    var environment = configuration.environment
    environment["RUFLET_PORT"] = environment["RUFLET_PORT"] ?? "0"
    environment["RUFLET_RUNTIME_PORT_FILE"] = configuration.portFile
    environment["RUFLET_RUNTIME_ERROR_FILE"] = configuration.errorFile
    environment["RUFLET_SUPPRESS_SERVER_BANNER"] = "1"

    let environmentKeys = Array(environment.keys)
    let loadPathCount = configuration.loadPaths.count
    let environmentCount = environmentKeys.count

    let status = withCStrings(configuration.loadPaths) { loadPaths in
      withCStrings(environmentKeys) { keys in
        withCStrings(environmentKeys.map { environment[$0]! }) { values in
          configuration.projectRoot.withCString { root in
            configuration.entrypoint.withCString { entrypoint in
              configuration.stopFile.withCString { stopFile in
                configuration.errorFile.withCString { errorFile in
                  startVM(
                    root, entrypoint,
                    loadPaths, loadPathCount,
                    keys, values, environmentCount,
                    stopFile, errorFile)
                }
              }
            }
          }
        }
      }
    }
    guard status == 0 else { throw StartupError.rejectedEntrypoint(status) }

    return try waitForPort(timeout: timeout)
  }

  /// Polls the port file the way the Objective-C bridge does. Call off the main
  /// thread — this blocks until the runtime answers.
  public func waitForPort(timeout: TimeInterval) throws -> Int {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if let published = try? String(contentsOfFile: configuration.portFile, encoding: .utf8),
        let port = Int(published.trimmingCharacters(in: .whitespacesAndNewlines)),
        port > 0
      {
        return port
      }
      if let failure = try? String(contentsOfFile: configuration.errorFile, encoding: .utf8),
        !failure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      {
        throw StartupError.runtimeReported(failure)
      }
      Thread.sleep(forTimeInterval: 0.001)
    }
    throw StartupError.portNotPublished(timeout)
  }

  /// Bridges `[String]` to the `const char *const *` the VM host expects,
  /// keeping every buffer alive for the duration of the call.
  private func withCStrings<R>(
    _ values: [String],
    _ body: (UnsafePointer<UnsafePointer<CChar>?>) -> R
  ) -> R {
    var buffers = values.map { strdup($0) }
    defer { buffers.forEach { free($0) } }
    return buffers.withUnsafeBufferPointer { pointer in
      body(UnsafeRawPointer(pointer.baseAddress!).assumingMemoryBound(to: UnsafePointer<CChar>?.self))
    }
  }
}

/// Finds the Ruby project a self-contained build packaged into the app bundle.
///
/// The project can be an ordinary bundle resource in a Swift-only shell or a
/// Flutter asset in the hybrid template. In both cases it is the directory
/// holding `main.rb`, and `RufletEmbeddedProject` in `Info.plist` names it when
/// a bundle carries more than one.
public enum BundledProject {
  public static func locate(in bundle: Bundle = .main) -> String? {
    let files = FileManager.default
    var roots: [String] = []
    if let resources = bundle.resourcePath {
      roots.append(resources)
    }
    if let frameworks = bundle.privateFrameworksPath {
      roots.append(
        (frameworks as NSString).appendingPathComponent("App.framework/flutter_assets/assets"))
    }

    if let configured = bundle.object(forInfoDictionaryKey: "RufletEmbeddedProject") as? String,
      !configured.isEmpty
    {
      for root in roots {
        let candidate = (root as NSString).appendingPathComponent(configured)
        if files.fileExists(atPath: (candidate as NSString).appendingPathComponent("main.rb")) {
          return candidate
        }
      }
      return nil
    }

    var found: String?
    for root in roots {
      if files.fileExists(atPath: (root as NSString).appendingPathComponent("main.rb")) {
        if found != nil { return nil }
        found = root
      }

      let entries = (try? files.contentsOfDirectory(atPath: root)) ?? []
      for entry in entries {
        let candidate = (root as NSString).appendingPathComponent(entry)
        guard files.fileExists(atPath: (candidate as NSString).appendingPathComponent("main.rb"))
        else { continue }
        // Ambiguous: the app must name one in Info.plist.
        if found != nil { return nil }
        found = candidate
      }
    }
    return found
  }
}
