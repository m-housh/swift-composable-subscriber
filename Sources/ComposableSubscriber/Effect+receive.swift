import ComposableArchitecture
import OSLog

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

extension Effect where Action: ReceiveAction {

  public static func receive(
    _ operation: @escaping () async throws -> Action.ReceiveAction
  ) -> Self {
    .run { send in
      await send(.receive(
        TaskResult { try await operation() }
      ))
    }
  }

  public static func receive<T>(
    _ operation: @escaping () async throws -> T,
    transform: @escaping (T) -> Action.ReceiveAction
  ) -> Self {
    .run { send in
      await send(.receive(
        TaskResult { try await operation() }
          .map(transform)
      ))
    }
  }

  public static func receive<T>(
    _ toReceiveAction: CaseKeyPath<Action.ReceiveAction, T>,
    _ operation: @escaping () async throws -> T
  ) -> Self {
    return .receive(operation) {
      AnyCasePath(toReceiveAction).embed($0)
    }
  }
}

