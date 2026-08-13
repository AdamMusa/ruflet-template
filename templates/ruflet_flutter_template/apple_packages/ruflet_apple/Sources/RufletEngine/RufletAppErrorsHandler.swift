import Foundation

@MainActor
public final class RufletAppErrorsHandler: ObservableObject {
  @Published public private(set) var error: String?

  public init() {}

  public func onError(_ error: String) {
    self.error = error
  }
}
