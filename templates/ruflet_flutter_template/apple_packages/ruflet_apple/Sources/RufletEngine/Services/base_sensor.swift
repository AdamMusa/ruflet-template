import Foundation
import RufletProtocol

@MainActor
open class BaseSensorService<Event>: RufletService {
  private var enabled = true
  private var hasReadingSubscribers = false
  private var hasErrorSubscribers = false
  private var interval: TimeInterval = 0.2
  private var cancelOnError = true

  open var defaultInterval: TimeInterval { 0.2 }
  open var eventName: String { "reading" }

  open func startSensor(samplingPeriod: TimeInterval) {
    preconditionFailure("BaseSensorService.startSensor must be overridden")
  }

  open func stopSensor() {}

  open func serializeEvent(_ event: Event) -> RufletValue {
    preconditionFailure("BaseSensorService.serializeEvent must be overridden")
  }

  open override func initialize() {
    updateConfiguration(forceRestart: true)
  }

  open override func update() {
    updateConfiguration()
  }

  public final func receive(_ event: Event) {
    guard hasReadingSubscribers else { return }
    control.triggerEvent(eventName, data: serializeEvent(event))
  }

  public final func receive(error: Error) {
    if hasErrorSubscribers {
      control.triggerEvent("error", data: ["message": .string(String(describing: error))])
    }
    if cancelOnError { stopSensor() }
  }

  private func updateConfiguration(forceRestart: Bool = false) {
    let nextEnabled = control.boolean("enabled", default: true)
    var nextInterval = serviceDuration(control.value("interval"), defaultValue: defaultInterval)
    if nextInterval < 0 { nextInterval = defaultInterval }
    let nextReadingSubscribers = control.hasEventHandler(eventName)
    let nextErrorSubscribers = control.hasEventHandler("error")
    let nextCancelOnError = control.boolean("cancel_on_error", default: true)

    guard forceRestart || nextEnabled != enabled || nextInterval != interval
      || nextReadingSubscribers != hasReadingSubscribers
      || nextErrorSubscribers != hasErrorSubscribers || nextCancelOnError != cancelOnError
    else { return }

    enabled = nextEnabled
    interval = nextInterval
    hasReadingSubscribers = nextReadingSubscribers
    hasErrorSubscribers = nextErrorSubscribers
    cancelOnError = nextCancelOnError
    restart()
  }

  private func restart() {
    stopSensor()
    guard enabled, hasReadingSubscribers || hasErrorSubscribers else { return }
    startSensor(samplingPeriod: interval)
  }

  open override func dispose() {
    stopSensor()
  }
}

private func serviceDuration(_ value: RufletValue?, defaultValue: TimeInterval) -> TimeInterval {
  guard let value else { return defaultValue }
  if let milliseconds = value.number { return milliseconds / 1_000 }
  guard let map = value.map else { return defaultValue }
  return (map["days"]?.number ?? 0) * 86_400
    + (map["hours"]?.number ?? 0) * 3_600
    + (map["minutes"]?.number ?? 0) * 60
    + (map["seconds"]?.number ?? 0)
    + (map["milliseconds"]?.number ?? 0) / 1_000
    + (map["microseconds"]?.number ?? 0) / 1_000_000
}

