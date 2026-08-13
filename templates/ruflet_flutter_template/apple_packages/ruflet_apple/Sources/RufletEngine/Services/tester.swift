import CoreGraphics
import Foundation
import RufletProtocol

@MainActor
public final class TesterService: RufletInvokableService {
  private var finders: [Int: RufletTestFinder] = [:]

  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    guard let tester = (control.backend as? RufletTestingBackend)?.tester else {
      throw RufletServiceError.unavailable("Tester is not configured")
    }
    switch name {
    case "pump": try await tester.pump(duration: testerDuration(arguments["duration"])); return nil
    case "pump_and_settle":
      try await tester.pumpAndSettle(duration: testerDuration(arguments["duration"])); return nil
    case "find_by_text":
      guard let text = arguments["text"]?.text else { throw RufletServiceError.missingArgument("text") }
      return remember(tester.findByText(text)).value
    case "find_by_text_containing":
      guard let pattern = arguments["pattern"]?.text else { throw RufletServiceError.missingArgument("pattern") }
      return remember(tester.findByTextContaining(pattern)).value
    case "find_by_key":
      guard let key = arguments["key"] else { throw RufletServiceError.missingArgument("key") }
      return remember(try tester.findByKey(key)).value
    case "find_by_tooltip":
      guard let value = arguments["value"]?.text else { throw RufletServiceError.missingArgument("value") }
      return remember(tester.findByTooltip(value)).value
    case "find_by_icon":
      guard let icon = arguments["icon"] else { throw RufletServiceError.missingArgument("icon") }
      return remember(try tester.findByIcon(icon)).value
    case "take_screenshot":
      guard let name = arguments["name"]?.text else { throw RufletServiceError.missingArgument("name") }
      return .binary(try await tester.takeScreenshot(name))
    case "tap":
      if let finder = finder(arguments) { try await tester.tap(finder, index: finderIndex(arguments)) }
      return nil
    case "tap_at":
      if let point = point(arguments["offset"]) { try await tester.tapAt(point) }
      return nil
    case "long_press":
      if let finder = finder(arguments) { try await tester.longPress(finder, index: finderIndex(arguments)) }
      return nil
    case "enter_text":
      if let finder = finder(arguments) {
        try await tester.enterText(finder, index: finderIndex(arguments), text: arguments["text"]?.text ?? "")
      }
      return nil
    case "mouse_hover":
      if let finder = finder(arguments) { try await tester.mouseHover(finder, index: finderIndex(arguments)) }
      return nil
    case "teardown": tester.teardown(); return nil
    default: throw RufletServiceError.unknownMethod(service: "Tester", method: name)
    }
  }

  private func remember(_ finder: RufletTestFinder) -> RufletTestFinder {
    finders[finder.id] = finder
    return finder
  }

  private func finder(_ arguments: [String: RufletValue]) -> RufletTestFinder? {
    arguments["finder_id"]?.integer.flatMap { finders[$0] }
  }

  private func finderIndex(_ arguments: [String: RufletValue]) -> Int {
    arguments["finder_index"]?.integer ?? 0
  }

  private func point(_ value: RufletValue?) -> CGPoint? {
    if let array = value?.array, array.count > 1 {
      return CGPoint(x: array[0].number ?? 0, y: array[1].number ?? 0)
    }
    guard let map = value?.map else { return nil }
    return CGPoint(x: map["x"]?.number ?? 0, y: map["y"]?.number ?? 0)
  }
}

private func testerDuration(_ value: RufletValue?) -> TimeInterval? {
  guard let value else { return nil }
  if let milliseconds = value.number { return milliseconds / 1_000 }
  guard let map = value.map else { return nil }
  return (map["days"]?.number ?? 0) * 86_400
    + (map["hours"]?.number ?? 0) * 3_600
    + (map["minutes"]?.number ?? 0) * 60
    + (map["seconds"]?.number ?? 0)
    + (map["milliseconds"]?.number ?? 0) / 1_000
    + (map["microseconds"]?.number ?? 0) / 1_000_000
}
