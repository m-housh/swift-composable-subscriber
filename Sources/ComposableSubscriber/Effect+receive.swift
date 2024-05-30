import ComposableArchitecture
import OSLog

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

