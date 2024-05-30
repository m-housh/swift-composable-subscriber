import ComposableArchitecture
import OSLog

extension Effect {
  
  @usableFromInline
  static func receive<T>(
    _ casePath: AnyCasePath<Action, TaskResult<T>>,
    _ operation: @escaping @Sendable () async throws -> T
  ) -> Self {
    .run { send in
      await send(casePath.embed(
        TaskResult { try await operation() }
      ))
    }
  }
  
  @usableFromInline
  static func receive<T, V>(
    _ casePath: AnyCasePath<Action, TaskResult<V>>,
    _ operation: @escaping @Sendable () async throws -> T,
    _ transform: @escaping @Sendable (T) -> V
  ) -> Self {
    .run { send in
      await send(casePath.embed(
        TaskResult { try await operation() }
          .map(transform)
      ))
    }
  }

  @inlinable
  public static func receive<T>(
    action toResult: CaseKeyPath<Action, TaskResult<T>>,
    operation: @escaping @Sendable () async throws -> T
  ) -> Self {
    .receive(AnyCasePath(toResult), operation)
  }
  
  @inlinable
  public static func receive<T, V>(
    action toResult: CaseKeyPath<Action, TaskResult<V>>,
    operation: @escaping @Sendable () async throws -> T,
    transform: @escaping @Sendable (T) -> V
  ) -> Self {
    .receive(AnyCasePath(toResult), operation, transform)
  }
}

extension Effect where Action: ReceiveAction {
  
  @inlinable
  public static func receive<T>(
    _ operation: @escaping @Sendable () async throws -> T,
    transform: @escaping @Sendable (T) -> Action.ReceiveAction
  ) -> Self {
    .receive(AnyCasePath(unsafe: Action.receive), operation, transform)
  }

  @inlinable
  public static func receive<T>(
    _ toReceiveAction: CaseKeyPath<Action.ReceiveAction, T>,
    _ operation: @escaping @Sendable () async throws -> T
  ) -> Self {
    return .receive(operation) {
      AnyCasePath(toReceiveAction).embed($0)
    }
  }
}

