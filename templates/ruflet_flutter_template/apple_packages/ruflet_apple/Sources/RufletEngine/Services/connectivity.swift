import Foundation
import Network
import RufletProtocol

@MainActor
public final class ConnectivityService: RufletInvokableService {
  private var monitor: NWPathMonitor?
  private var latest: [String] = ["none"]

  public override func initialize() {
    super.initialize()
    refreshCurrentPath()
    updateListeners()
  }

  public override func update() { updateListeners() }

  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    guard name == "get_connectivity" else {
      throw RufletServiceError.unknownMethod(service: "Connectivity", method: name)
    }
    return .array(latest.map(RufletValue.string))
  }

  private func updateListeners() {
    let shouldListen = control.hasEventHandler("change")
    if shouldListen, monitor == nil {
      let nextMonitor = NWPathMonitor()
      nextMonitor.pathUpdateHandler = { [weak self] path in
        Task { @MainActor in
          guard let self else { return }
          self.latest = Self.results(for: path)
          self.control.triggerEvent("change", data: [
            "connectivity": .array(self.latest.map(RufletValue.string))
          ])
        }
      }
      monitor = nextMonitor
      nextMonitor.start(queue: DispatchQueue(label: "dev.ruflet.connectivity"))
    } else if !shouldListen {
      monitor?.cancel()
      monitor = nil
    }
  }

  private func refreshCurrentPath() {
    let currentMonitor = NWPathMonitor()
    latest = Self.results(for: currentMonitor.currentPath)
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
    super.dispose()
  }
}

