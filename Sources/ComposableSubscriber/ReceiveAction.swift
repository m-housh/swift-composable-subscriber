import ComposableArchitecture

public protocol ReceiveAction<ReceiveAction> {
  associatedtype ReceiveAction
  static func receive(_ result: TaskResult<ReceiveAction>) -> Self

  var result: TaskResult<ReceiveAction>? { get }
}

extension ReceiveAction {

  public var result: TaskResult<ReceiveAction>? {
    AnyCasePath(unsafe: Self.receive).extract(from: self)
  }
}
