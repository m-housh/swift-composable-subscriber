import ComposableArchitecture

extension Reducer {

  /// A higher order reducer that sends a receive action on a trigger action.
  ///
  /// ## Example
  /// ```swift
  ///
  /// @Reducer
  /// struct MyFeature {
  ///   ...
  ///
  ///   enum Action {
  ///     case receive(TaskResult<Int>)
  ///     case task
  ///   }
  ///
  ///   @Dependency(\.numberClient) var numberClient
  ///
  ///   var body: some ReducerOf<Self> {
  ///     Reduce { state, action in
  ///       ...
  ///     }
  ///     .receive(on: \.task, with: \.receive) {
  ///       try await numberClient.fetchCurrentNumber()
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - triggerAction: The action that triggers calling the result handler.
  ///   - receiveAction: The action that receives the task result.
  ///   - resultHandler: The operations that is called that returns the value to be received.
  ///
  @inlinable
  public func receive<TriggerAction, Value>(
    on triggerAction: CaseKeyPath<Action, TriggerAction>,
    with receiveAction: CaseKeyPath<Action, TaskResult<Value>>,
    result resultHandler: @escaping @Sendable () async throws -> Value
  ) -> _ReceiveOnTriggerReducer<Self, TriggerAction, Value, Value> {
    .init(
      parent: self,
      triggerAction: { AnyCasePath(triggerAction).extract(from: $0) },
      receiveOperation: .case(AnyCasePath(receiveAction), resultHandler)
    )
  }

}

extension Reducer where Action: ReceiveAction {
  /// A higher order reducer that sends a receive action on a trigger action.
  ///
  /// ## Example
  /// ```swift
  ///
  /// @Reducer
  /// struct MyFeature {
  ///   ...
  ///
  ///   enum Action: ReceiveAction {
  ///     case receive(TaskResult<ReceiveAction>)
  ///     case task
  ///
  ///     @CasePathable
  ///     enum ReceiveAction {
  ///       case currentNumber(Int)
  ///       ...
  ///     }
  ///   }
  ///
  ///   @Dependency(\.numberClient) var numberClient
  ///
  ///   var body: some ReducerOf<Self> {
  ///     Reduce { state, action in
  ///       ...
  ///     }
  ///     .receive(on: \.task, case: \.currentNumber) {
  ///       try await numberClient.fetchCurrentNumber()
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - triggerAction: The action that triggers calling the result handler.
  ///   - embedCasePath: The case path to embed the result into.
  ///   - resultHandler: The operations that is called that returns the value to be received.
  @inlinable
  public func receive<TriggerAction, Value>(
    on triggerAction: CaseKeyPath<Action, TriggerAction>,
    case embedCasePath: CaseKeyPath<Action.ReceiveAction, Value>,
    result resultHandler: @escaping @Sendable () async throws -> Value
  ) -> _ReceiveOnTriggerReducer<Self, TriggerAction, Value, Action.ReceiveAction> {
    .init(
      parent: self,
      triggerAction: { AnyCasePath(triggerAction).extract(from: $0) },
      receiveOperation: .case(AnyCasePath(embedCasePath), resultHandler)
    )

  }
}

public struct _ReceiveOnTriggerReducer<
  Parent: Reducer,
  TriggerAction,
  Value,
  Result
>: Reducer {

  @usableFromInline
  let parent: Parent

  @usableFromInline
  let triggerAction: @Sendable (Parent.Action) -> TriggerAction?

  @usableFromInline
  let receiveOperation:  ReceiveOperation<Parent.Action, Value, Result>

  @usableFromInline
  init(
    parent: Parent,
    triggerAction: @escaping @Sendable (Parent.Action) -> TriggerAction?,
    receiveOperation: ReceiveOperation<Parent.Action, Value, Result>
  ) {
    self.parent = parent
    self.triggerAction = triggerAction
    self.receiveOperation = receiveOperation
  }

  @inlinable
  public func reduce(
    into state: inout Parent.State,
    action: Parent.Action) -> Effect<Parent.Action>
  {
    let baseEffects = parent.reduce(into: &state, action: action)

    guard triggerAction(action) != nil else {
      return baseEffects
    }

    return .merge(
      baseEffects,
      .receive(operation: receiveOperation)
    )
  }
}

