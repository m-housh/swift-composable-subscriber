import ComposableArchitecture

extension Effect {
  
  @usableFromInline
  static func receive<Input, Result>(
    operation: ReceiveOperation<Action, Input, Result>
  ) -> Self {
    .run { send in
      await operation(send: send)
    }
  }

  @inlinable
  public static func receive<T>(
    action toResult: CaseKeyPath<Action, TaskResult<T>>,
    operation: @escaping @Sendable () async throws -> T
  ) -> Self {
    .receive(operation: .case(AnyCasePath(toResult), operation))
  }
  
  @inlinable
  public static func receive<T, V>(
    action toResult: CaseKeyPath<Action, TaskResult<V>>,
    operation: @escaping @Sendable () async throws -> T,
    transform: @escaping @Sendable (T) -> V
  ) -> Self {
    .receive(operation: .case(AnyCasePath(toResult), operation, transform))
  }
}

extension Effect where Action: ReceiveAction {
  
  @inlinable
  public static func receive<T>(
    _ operation: @escaping @Sendable () async throws -> T,
    transform: @escaping @Sendable (T) -> Action.ReceiveAction
  ) -> Self {
    .receive(operation: .case(AnyCasePath(unsafe: Action.receive), operation, transform))
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

@usableFromInline
struct ReceiveOperation<Action, Input, Result> {
  
  @usableFromInline
  let embed: @Sendable (TaskResult<Result>) -> Action
  
  @usableFromInline
  let operation: @Sendable () async throws -> Input
  
  @usableFromInline
  let transform: @Sendable (Input) -> Result
  
  @usableFromInline
  func callAsFunction(send: Send<Action>) async {
    await send(embed(
      TaskResult { try await operation() }
        .map(transform)
    ))
  }
   
  @usableFromInline
  static func `case`(
    _ casePath: AnyCasePath<Action, TaskResult<Result>>,
    _ operation: @escaping @Sendable () async throws -> Input,
    _ transform: @escaping @Sendable (Input) -> Result
  ) -> Self {
    .init(embed: { casePath.embed($0) }, operation: operation, transform: transform)
  }
}

extension ReceiveOperation where Input == Result {
  
  @usableFromInline
  init(
    embed: @escaping @Sendable (TaskResult<Result>) -> Action,
    operation: @escaping @Sendable () async throws -> Input
  ) {
    self.init(embed: embed, operation: operation, transform: { $0 })
  }
  
  @usableFromInline
  static func `case`(
    _ casePath: AnyCasePath<Action, TaskResult<Result>>,
    _ operation: @escaping @Sendable () async throws -> Input
  ) -> Self {
    .init(embed: { casePath.embed($0) }, operation: operation)
  }
}
