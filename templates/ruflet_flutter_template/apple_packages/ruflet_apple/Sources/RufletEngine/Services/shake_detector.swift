import CoreMotion
import Foundation
import RufletProtocol

@MainActor
public final class ShakeDetectorService: RufletService {
  #if os(iOS)
  private let motionManager = CMMotionManager()
  private let queue = OperationQueue()
  #endif
  private var shakeTimestamp = Int(Date().timeIntervalSince1970 * 1_000)
  private var shakeCount = 0
  private var minimumShakeCount = 1
  private var shakeSlopTimeMS = 500
  private var shakeCountResetTimeMS = 3_000
  private var shakeThresholdGravity = 2.7

  public override func initialize() { update() }

  public override func update() {
    let nextMinimum = control.integer("minimum_shake_count", default: 1) ?? 1
    let nextSlop = control.integer("shake_slop_time_ms", default: 500) ?? 500
    let nextReset = control.integer("shake_count_reset_time_ms", default: 3_000) ?? 3_000
    let nextThreshold = control.number("shake_threshold_gravity", default: 2.7) ?? 2.7
    guard nextMinimum != minimumShakeCount || nextSlop != shakeSlopTimeMS
      || nextReset != shakeCountResetTimeMS || nextThreshold != shakeThresholdGravity
      || !isListening else { return }
    minimumShakeCount = nextMinimum
    shakeSlopTimeMS = nextSlop
    shakeCountResetTimeMS = nextReset
    shakeThresholdGravity = nextThreshold
    stopListening()
    startListening()
  }

  private var isListening: Bool {
    #if os(iOS)
    motionManager.isAccelerometerActive
    #else
    false
    #endif
  }

  private func startListening() {
    #if os(iOS)
    guard motionManager.isAccelerometerAvailable else { return }
    motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
      guard let acceleration = data?.acceleration else { return }
      Task { @MainActor in
        self?.processGravity(x: acceleration.x, y: acceleration.y, z: acceleration.z)
      }
    }
    #endif
  }

  private func processGravity(x: Double, y: Double, z: Double) {
    let force = sqrt(x * x + y * y + z * z)
    guard force > shakeThresholdGravity else { return }
    let now = Int(Date().timeIntervalSince1970 * 1_000)
    guard shakeTimestamp + shakeSlopTimeMS <= now else { return }
    if shakeTimestamp + shakeCountResetTimeMS < now { shakeCount = 0 }
    shakeTimestamp = now
    shakeCount += 1
    if shakeCount >= minimumShakeCount { control.triggerEvent("shake") }
  }

  private func stopListening() {
    #if os(iOS)
    motionManager.stopAccelerometerUpdates()
    #endif
  }

  public override func dispose() { stopListening() }
}
