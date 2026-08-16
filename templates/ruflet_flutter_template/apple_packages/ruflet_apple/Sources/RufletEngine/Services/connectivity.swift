import Foundation
import Network
import RufletProtocol

@MainActor
public final class ConnectivityService: RufletInvokableService {
  private var monitor: NWPathMonitor?
  private var latest: [String] = ["none"]
  private var pathReady = false
  private var pathWaiters: [CheckedContinuation<[String], Never>] = []

  public override func initialize() {
    super.initialize()
    startMonitor()
  }

  public override func update() {}

  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    guard name == "get_connectivity" else {
      throw RufletServiceError.unknownMethod(service: "Connectivity", method: name)
    }
    let current = pathReady
      ? latest
      : await withCheckedContinuation { pathWaiters.append($0) }
    return .array(current.map(RufletValue.string))
  }

  private func startMonitor() {
    guard monitor == nil else { return }
    let nextMonitor = NWPathMonitor()
    nextMonitor.pathUpdateHandler = { [weak self] path in
      Task { @MainActor in
        guard let self else { return }
        let next = Self.results(for: path)
        let changed = next != self.latest
        self.latest = next
        self.pathReady = true
        let waiters = self.pathWaiters
        self.pathWaiters.removeAll()
        waiters.forEach { $0.resume(returning: next) }
        if changed, self.control.hasEventHandler("change") {
          self.control.triggerEvent("change", data: [
            "connectivity": .array(self.latest.map(RufletValue.string))
          ])
        }
      }
    }
    monitor = nextMonitor
    // NWPathMonitor.currentPath is not populated until the monitor starts.
    // Keeping one monitor alive makes get_connectivity return the actual last
    // path even when the Ruby control did not subscribe to on_change.
    nextMonitor.start(queue: DispatchQueue(label: "dev.ruflet.connectivity"))
  }

  private static func results(for path: NWPath) -> [String] {
    guard path.status == .satisfied else { return ["none"] }
    var values: [String] = []
    if path.usesInterfaceType(.wifi) { values.append("wifi") }
    if path.usesInterfaceType(.wiredEthernet) { values.append("ethernet") }
    if path.usesInterfaceType(.cellular) { values.append("mobile") }
    if path.usesInterfaceType(.other) { values.append("other") }
    return values.isEmpty ? ["other"] : values
  }

  public override func dispose() {
    monitor?.cancel()
    monitor = nil
    pathWaiters.forEach { $0.resume(returning: latest) }
    pathWaiters.removeAll()
    super.dispose()
  }
}
