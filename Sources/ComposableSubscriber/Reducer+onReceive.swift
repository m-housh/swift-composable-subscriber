import ComposableArchitecture
import OSLog

extension Reducer {
  
  @usableFromInline
  func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, V>,
    set setAction: SetAction<State, Action, V>
  ) -> _OnReceiveReducer<Self, V> {
    .init(
      parent: self,
      receiveAction: { AnyCasePath(toReceiveAction).extract(from: $0) },
      setAction: setAction
    )
  }
  
  @inlinable
  public func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, V>,
    set setAction: @escaping (inout State, V) -> Effect<Action>
  ) -> _OnReceiveReducer<Self, V> {
    self.onReceive(
      action: toReceiveAction,
      set: .operation(f: setAction)
    )
  }

  @inlinable
  public func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, V>,
    set setAction: @escaping (inout State, V) -> Void
  ) -> _OnReceiveReducer<Self, V> {
    self.onReceive(
      action: toReceiveAction,
      set: .operation(f: { state, value in
        setAction(&state, value)
        return .none
      })
    )
  }

  @inlinable
  public func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, V>,
    set toStateKeyPath: WritableKeyPath<State, V>,
    effect: Effect<Action> = .none
  ) -> _OnReceiveReducer<Self, V> {
    self.onReceive(
      action: toReceiveAction,
      set: .keyPath(toStateKeyPath, effect: effect)
    )
  }
  
  @inlinable
  public func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, V>,
    set toStateKeyPath: WritableKeyPath<State, V?>,
    effect: Effect<Action> = .none
  ) -> _OnReceiveReducer<Self, V> {
    self.onReceive(
      action: toReceiveAction,
      set: .optionalKeyPath(toStateKeyPath, effect: effect)
    )
  }
  
  @usableFromInline
  func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, TaskResult<V>>,
    onFail: OnFailAction<State, Action>? = nil,
    onSuccess setAction: SetAction<State, Action, V>
  ) -> _OnReceiveReducer<Self, TaskResult<V>> {
    self.onReceive(action: toReceiveAction) { state, result in
      switch result {
      case let .failure(error):
        if let onFail {
          return onFail(state: &state, error: error)
        }
        return .none
      case let .success(value):
        return setAction(state: &state, value: value)
      }
    }
  }
  
  @inlinable
  public func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, TaskResult<V>>,
    onSuccess setAction: @escaping (inout State, V) -> Void,
    onFail: OnFailAction<State, Action>? = nil
  ) -> _OnReceiveReducer<Self, TaskResult<V>> {
    self.onReceive(
      action: toReceiveAction,
      onFail: onFail,
      onSuccess: .operation(setAction)
    )
  }
  
  @inlinable
  public func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, TaskResult<V>>,
    set toStateKeyPath: WritableKeyPath<State, V>,
    onFail: OnFailAction<State, Action>? = nil,
    effect: Effect<Action> = .none
  ) -> _OnReceiveReducer<Self, TaskResult<V>> {
     self.onReceive(
      action: toReceiveAction,
      onFail: onFail,
      onSuccess: .keyPath(toStateKeyPath, effect: effect)
    )
  }
  
  @inlinable
  public func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, TaskResult<V>>,
    set toStateKeyPath: WritableKeyPath<State, V?>,
    onFail: OnFailAction<State, Action>? = nil,
    effect: Effect<Action> = .none
  ) -> _OnReceiveReducer<Self, TaskResult<V>> {
     self.onReceive(
      action: toReceiveAction,
      onFail: onFail,
      onSuccess: .optionalKeyPath(toStateKeyPath, effect: effect)
    )
  }

  @inlinable
  public func receive<TriggerAction, Value>(
    on triggerAction: CaseKeyPath<Action, TriggerAction>,
    with receiveAction: CaseKeyPath<Action, TaskResult<Value>>,
    result resultHandler: @escaping @Sendable () async throws -> Value
  ) -> _ReceiveOnTriggerReducer<Self, TriggerAction, Value> {
    .init(
      parent: self,
      triggerAction: { AnyCasePath(triggerAction).extract(from: $0) },
      toReceiveAction: { AnyCasePath(receiveAction).embed($0) },
      resultHandler: resultHandler
    )
  }

}

extension Reducer where Action: ReceiveAction {
  @inlinable
  public func receive<TriggerAction, Value>(
    on triggerAction: CaseKeyPath<Action, TriggerAction>,
    case embedCasePath: CaseKeyPath<Action.ReceiveAction, Value>,
    result resultHandler: @escaping @Sendable () async throws -> Value
  ) -> _ReceiveOnTriggerReducer<Self, TriggerAction, Action.ReceiveAction> {
    .init(
      parent: self,
      triggerAction: { AnyCasePath(triggerAction).extract(from: $0) },
      toReceiveAction: { AnyCasePath(unsafe: Action.receive).embed($0) },
      resultHandler: {
        try await AnyCasePath(embedCasePath).embed(
          resultHandler()
        )
      }
    )
  }
}

public struct _OnReceiveReducer<Parent: Reducer, Value>: Reducer {
  
  @usableFromInline
  let parent: Parent
  
  @usableFromInline
  let receiveAction: (Parent.Action) -> Value?

  @usableFromInline
  let setAction: SetAction<Parent.State, Parent.Action, Value>

  @usableFromInline
  init(
    parent: Parent,
    receiveAction: @escaping (Parent.Action) -> Value?,
    setAction: SetAction<Parent.State, Parent.Action, Value>
  ) {
    self.parent = parent
    self.receiveAction = receiveAction
    self.setAction = setAction
  }

  @inlinable
  public func reduce(
    into state: inout Parent.State,
    action: Parent.Action
  ) -> Effect<Parent.Action> {
    let baseEffects = parent.reduce(into: &state, action: action)
    
    guard let value = receiveAction(action) else {
      return baseEffects
    }
    
    return .merge(
      baseEffects,
      setAction(state: &state, value: value)
    )
  }
}

public struct _ReceiveOnTriggerReducer<
  Parent: Reducer,
  TriggerAction,
  Value
>: Reducer {

  @usableFromInline
  let parent: Parent

  @usableFromInline
  let triggerAction: @Sendable (Parent.Action) -> TriggerAction?

  @usableFromInline
  let toReceiveAction: @Sendable (TaskResult<Value>) -> Parent.Action

  @usableFromInline
  let resultHandler: @Sendable () async throws -> Value

  @usableFromInline
  init(
    parent: Parent,
    triggerAction: @escaping @Sendable (Parent.Action) -> TriggerAction?,
    toReceiveAction: @escaping @Sendable (TaskResult<Value>) -> Parent.Action,
    resultHandler: @escaping @Sendable () async throws -> Value
  ) {
    self.parent = parent
    self.triggerAction = triggerAction
    self.toReceiveAction = toReceiveAction
    self.resultHandler = resultHandler
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
      .receive(operation: .init(embed: toReceiveAction, operation: resultHandler))
    )
  }
}

public struct ReceiveReducer<State, Action: ReceiveAction>: Reducer {

  @usableFromInline
  let toResult: (Action) -> TaskResult<Action.ReceiveAction>?

  @usableFromInline
  let onFail: OnFailAction<State, Action>?

  @usableFromInline
  let onSuccess: (inout State, Action.ReceiveAction) -> Effect<Action>

  @inlinable
  init(
    internal toResult: @escaping (Action) -> TaskResult<Action.ReceiveAction>?,
    onFail: OnFailAction<State, Action>?,
    onSuccess: @escaping(inout State, Action.ReceiveAction) -> Effect<Action>
  ) {
    self.toResult = toResult
    self.onFail = onFail
    self.onSuccess = onSuccess
  }

  @inlinable
  public init(
    onFail: OnFailAction<State, Action>? = nil,
    onSuccess: @escaping (inout State, Action.ReceiveAction) -> Effect<Action>
  ) {
    self.init(
      internal: {
        AnyCasePath(unsafe: Action.receive).extract(from: $0)
      },
      onFail: onFail,
      onSuccess: onSuccess
    )
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action> {
    guard let result = toResult(action) else { return .none }
    switch result {
    case let .failure(error):
      guard let onFail else { return .none }
      return onFail(state: &state, error: error)
    case let .success(value):
      return onSuccess(&state, value)
    }
  }

}
