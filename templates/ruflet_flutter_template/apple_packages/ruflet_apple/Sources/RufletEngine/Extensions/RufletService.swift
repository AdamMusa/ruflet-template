@MainActor
open class RufletService {
  public let control: RufletControl

  public required init(control: RufletControl) {
    self.control = control
  }

  open func initialize() {}
  open func update() {}
  open func dispose() {}
}
