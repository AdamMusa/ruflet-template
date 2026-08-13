import Foundation

@MainActor
public final class RufletRouteState: ObservableObject {
  @Published public private(set) var route = ""
  private let parser: RufletRouteParser

  public init(parser: RufletRouteParser = .init()) {
    self.parser = parser
  }

  public func go(_ route: String) {
    let parsed = parser.parse(route)
    guard parsed != self.route else { return }
    self.route = parsed
  }
}
