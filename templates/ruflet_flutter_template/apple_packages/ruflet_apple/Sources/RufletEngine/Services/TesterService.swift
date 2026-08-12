import Foundation
import RufletProtocol

public struct RufletTesterOffset: Equatable {
  public let x: Double
  public let y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
}

public enum RufletTesterQuery: Equatable {
  case text(String)
  case textContaining(String)
  case key(RufletTesterKey)
  case tooltip(String)
  case icon(RufletValue)
}

public enum RufletTesterKey: Equatable {
  case value(RufletValue)
  case scroll(RufletValue)
}

/// Host seam for operations that need mounted native views. The default driver
/// provides deterministic control-tree finding and event dispatch; XCTest or a
/// Ruflet app host can inject native hit testing and screenshot capture.
@MainActor
public protocol RufletTesterDriver: AnyObject {
  func pump(durationMilliseconds: Double?, settle: Bool) async throws
  func find(_ query: RufletTesterQuery, in store: ControlStore) throws -> [Int]
  func takeScreenshot(name: String) async throws -> [UInt8]
  func tap(controlID: Int, context: RufletServiceContext) async throws
  func tap(at offset: RufletTesterOffset, context: RufletServiceContext) async throws
  func longPress(controlID: Int, context: RufletServiceContext) async throws
  func enterText(controlID: Int, text: String, context: RufletServiceContext) async throws
  func mouseHover(controlID: Int, context: RufletServiceContext) async throws
  func teardown()
}

public enum FletTesterSemantics {
  public static func durationMilliseconds(_ value: RufletValue?) -> Double? {
    switch value {
    case nil, .null: return nil
    case .int(let value): return Double(value)
    case .double(let value): return value.isFinite ? Double(Int(value)) : nil
    case .extended(type: 3, let microseconds):
      return Double(microseconds).map { $0 / 1_000 }
    case .map(let values):
      func integer(_ key: String) -> Double { Double(values[key]?.intValue ?? 0) }
      return
        86_400_000 * integer("days") + 3_600_000 * integer("hours")
        + 60_000 * integer("minutes") + 1_000 * integer("seconds")
        + integer("milliseconds") + integer("microseconds") / 1_000
    default: return nil
    }
  }

  public static func offset(_ value: RufletValue?) -> RufletTesterOffset? {
    guard let value, !value.isNull else { return nil }
    if let values = value.arrayValue, values.count > 1 {
      return RufletTesterOffset(
        x: values[0].doubleValue ?? 0, y: values[1].doubleValue ?? 0)
    }
    if let values = value.mapValue {
      return RufletTesterOffset(
        x: values["x"]?.doubleValue ?? 0, y: values["y"]?.doubleValue ?? 0)
    }
    return nil
  }

  public static func parsedKey(_ value: RufletValue?) throws -> RufletTesterKey {
    guard let value, !value.isNull else {
      throw RufletServiceError.invalidArguments("key is required")
    }
    guard let map = value.mapValue else { return .value(try keyValue(value)) }
    switch map["_type"]?.stringValue {
    case "value":
      guard let key = map["value"] else {
        throw RufletServiceError.invalidArguments("key.value is required")
      }
      return .value(try keyValue(key))
    case "scroll":
      guard let key = map["value"] else {
        throw RufletServiceError.invalidArguments("key.value is required")
      }
      return .scroll(try keyValue(key))
    default:
      throw RufletServiceError.invalidArguments(
        "Unknown key type: \(map["_type"]?.stringValue ?? "null")")
    }
  }

  public static func finderResult(id: Int, count: Int) -> RufletValue {
    .map(["id": .int(Int64(id)), "count": .int(Int64(count))])
  }

  private static func keyValue(_ value: RufletValue) throws -> RufletValue {
    switch value {
    case .bool, .int, .double, .string: return value
    default:
      throw RufletServiceError.invalidArguments(
        "key value must be an int, string, bool, or double")
    }
  }
}

@MainActor
public final class TesterService: RufletService {
  public static let wireType = "Tester"

  private struct Finder {
    let ids: [Int]
  }

  private static var nextFinderID = 0
  private var finders: [Int: Finder] = [:]
  private let driver: any RufletTesterDriver

  public init(driver: (any RufletTesterDriver)? = nil) {
    self.driver = driver ?? RufletControlTreeTesterDriver()
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    switch call.name {
    case "pump", "pump_and_settle":
      let durationValue = call.argument("duration")
      let duration = FletTesterSemantics.durationMilliseconds(durationValue)
      if let durationValue, !durationValue.isNull, duration == nil {
        return completion(.failure(RufletServiceError.invalidArguments("invalid duration")))
      }
      Task { @MainActor in
        do {
          try await driver.pump(
            durationMilliseconds: duration, settle: call.name == "pump_and_settle")
          completion(.success(.null))
        } catch { completion(.failure(error)) }
      }

    case "find_by_text":
      guard case .string(let text)? = call.argument("text") else {
        return completion(.failure(RufletServiceError.invalidArguments("text is required")))
      }
      find(.text(text), context, completion)
    case "find_by_text_containing":
      guard case .string(let pattern)? = call.argument("pattern") else {
        return completion(.failure(RufletServiceError.invalidArguments("pattern is required")))
      }
      find(.textContaining(pattern), context, completion)
    case "find_by_tooltip":
      guard case .string(let value)? = call.argument("value") else {
        return completion(.failure(RufletServiceError.invalidArguments("value is required")))
      }
      find(.tooltip(value), context, completion)
    case "find_by_key":
      do {
        find(.key(try FletTesterSemantics.parsedKey(call.argument("key"))), context, completion)
      } catch { completion(.failure(error)) }
    case "find_by_icon":
      guard let icon = call.argument("icon"), !icon.isNull else {
        return completion(.failure(RufletServiceError.invalidArguments("Icon not found: null")))
      }
      find(.icon(icon), context, completion)

    case "take_screenshot":
      guard case .string(let name)? = call.argument("name") else {
        return completion(.failure(RufletServiceError.invalidArguments("name is required")))
      }
      Task { @MainActor in
        do { completion(.success(.binary(try await driver.takeScreenshot(name: name)))) }
        catch { completion(.failure(error)) }
      }

    case "tap", "long_press", "enter_text", "mouse_hover":
      invokeFinderAction(call, context: context, completion: completion)

    case "tap_at":
      guard let offsetValue = call.argument("offset"), !offsetValue.isNull else {
        return completion(.success(.null))
      }
      guard let offset = FletTesterSemantics.offset(offsetValue) else {
        return completion(.failure(RufletServiceError.invalidArguments("invalid offset")))
      }
      Task { @MainActor in
        do {
          try await driver.tap(at: offset, context: context)
          completion(.success(.null))
        } catch { completion(.failure(error)) }
      }

    case "teardown":
      driver.teardown()
      completion(.success(.null))

    default:
      completion(.failure(RufletServiceError.unsupportedMethod(type: "Tester", method: call.name)))
    }
  }

  private func find(
    _ query: RufletTesterQuery,
    _ context: RufletServiceContext,
    _ completion: @escaping RufletMethodCompletion
  ) {
    do {
      let ids = try driver.find(query, in: context.store)
      let id = Self.nextFinderID
      Self.nextFinderID += 1
      finders[id] = Finder(ids: ids)
      completion(.success(FletTesterSemantics.finderResult(id: id, count: ids.count)))
    } catch { completion(.failure(error)) }
  }

  private func invokeFinderAction(
    _ call: RufletMethodCall,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    guard let finderID = call.argument("finder_id")?.intValue,
      let finder = finders[finderID]
    else {
      // Pinned Flet silently ignores actions whose finder id is absent/stale.
      return completion(.success(.null))
    }
    guard let index = call.argument("finder_index")?.intValue,
      finder.ids.indices.contains(index)
    else {
      return completion(.failure(RufletServiceError.invalidArguments("finder_index is out of range")))
    }
    let controlID = finder.ids[index]
    Task { @MainActor in
      do {
        switch call.name {
        case "tap": try await driver.tap(controlID: controlID, context: context)
        case "long_press": try await driver.longPress(controlID: controlID, context: context)
        case "enter_text":
          guard case .string(let text)? = call.argument("text") else {
            throw RufletServiceError.invalidArguments("text is required")
          }
          try await driver.enterText(controlID: controlID, text: text, context: context)
        case "mouse_hover": try await driver.mouseHover(controlID: controlID, context: context)
        default: break
        }
        completion(.success(.null))
      } catch { completion(.failure(error)) }
    }
  }
}

@MainActor
private final class RufletControlTreeTesterDriver: RufletTesterDriver {
  func pump(durationMilliseconds: Double?, settle: Bool) async throws {
    guard let durationMilliseconds, durationMilliseconds.isFinite, durationMilliseconds > 0 else {
      await Task.yield()
      return
    }
    try await Task.sleep(nanoseconds: UInt64(durationMilliseconds * 1_000_000))
  }

  func find(_ query: RufletTesterQuery, in store: ControlStore) throws -> [Int] {
    store.nodes.values.filter { node in
      guard node.bool("visible") != false else { return false }
      switch query {
      case .text(let value): return node.string("value") == value
      case .textContaining(let pattern): return node.string("value")?.contains(pattern) == true
      case .tooltip(let value): return node.string("tooltip") == value
      case .key(let value):
        return (try? FletTesterSemantics.parsedKey(node.props["key"])) == value
      case .icon(let value): return node.props["icon"] == value
      }
    }.map(\.id).sorted()
  }

  func takeScreenshot(name: String) async throws -> [UInt8] {
    throw RufletServiceError.unavailable(
      "Tester.take_screenshot requires a mounted native tester driver")
  }

  func tap(controlID: Int, context: RufletServiceContext) async throws {
    context.emitEvent(controlID, "click", .null)
  }

  func tap(at offset: RufletTesterOffset, context: RufletServiceContext) async throws {
    throw RufletServiceError.unavailable("Tester.tap_at requires native hit testing")
  }

  func longPress(controlID: Int, context: RufletServiceContext) async throws {
    context.emitEvent(controlID, "long_press", .null)
  }

  func enterText(controlID: Int, text: String, context: RufletServiceContext) async throws {
    context.store.setLocalProperty(controlID, key: "value", value: .string(text))
    context.emitEvent(controlID, "change", .string(text))
  }

  func mouseHover(controlID: Int, context: RufletServiceContext) async throws {
    context.emitEvent(controlID, "hover", .bool(true))
  }

  func teardown() {}
}
