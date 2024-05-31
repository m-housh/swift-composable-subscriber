import ComposableArchitecture

// A container that holds onto the required data for embedding a task result into
// an action and optionally transforming the output.
@usableFromInline
struct ReceiveOperation<Action, Value, Result> {

  @usableFromInline
  let embed: @Sendable (TaskResult<Result>) -> Action

  @usableFromInline
  let operation: @Sendable () async throws -> Value

  @usableFromInline
  let transform: @Sendable (Value) -> Result

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
    _ operation: @escaping @Sendable () async throws -> Value,
    _ transform: @escaping @Sendable (Value) -> Result
  ) -> Self {
    .init(embed: { casePath.embed($0) }, operation: operation, transform: transform)
  }

  @usableFromInline
  static func `case`(
    _ casePath: AnyCasePath<Action, TaskResult<Result>>,
    operation: @escaping @Sendable () async throws -> Value,
    embedIn embedInCase: AnyCasePath<Result, Value>
  ) -> Self {
    .case(casePath, operation) {
      embedInCase.embed($0)
    }
  }
}

extension ReceiveOperation where Value == Result {

  @usableFromInline
  init(
    embed: @escaping @Sendable (TaskResult<Result>) -> Action,
    operation: @escaping @Sendable () async throws -> Value
  ) {
    self.init(embed: embed, operation: operation, transform: { $0 })
  }

  @usableFromInline
  static func `case`(
    _ casePath: AnyCasePath<Action, TaskResult<Result>>,
    _ operation: @escaping @Sendable () async throws -> Value
  ) -> Self {
    .init(embed: { casePath.embed($0) }, operation: operation)
  }
}

extension ReceiveOperation where Action: ReceiveAction, Result == Action.ReceiveAction {

  @usableFromInline
  static func `case`(
    _ embedInCase: AnyCasePath<Action.ReceiveAction, Value>,
    _ operation: @escaping @Sendable () async throws -> Value
  ) -> Self {
    .case(
      AnyCasePath(unsafe: Action.receive),
      operation: operation,
      embedIn: embedInCase
    )
  }
}
