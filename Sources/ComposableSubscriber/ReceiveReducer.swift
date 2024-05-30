import ComposableArchitecture
import OSLog

extension Reducer {
  
  @inlinable
  public func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, V>,
    set setAction: @escaping (inout State, V) -> Effect<Action>
  ) -> _ReceiveReducer<Self, V> {
    .init(
      parent: self,
      receiveAction: { AnyCasePath(toReceiveAction).extract(from: $0) },
      setAction: setAction
    )
  }

  @inlinable
  public func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, V>,
    set setAction: @escaping (inout State, V) -> Void
  ) -> _ReceiveReducer<Self, V> {
    .init(
      parent: self,
      receiveAction: { AnyCasePath(toReceiveAction).extract(from: $0) },
      setAction: { state, value in
        setAction(&state, value)
        return .none
      }
    )
  }

  @inlinable
  public func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, V>,
    set toStateKeyPath: WritableKeyPath<State, V>
  ) -> _ReceiveReducer<Self, V> {
    self.onReceive(action: toReceiveAction, set: toStateKeyPath.callAsFunction(root:value:))
  }
  
  @inlinable
  public func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, V>,
    set toStateKeyPath: WritableKeyPath<State, V?>
  ) -> _ReceiveReducer<Self, V> {
    self.onReceive(action: toReceiveAction, set: toStateKeyPath.callAsFunction(root:value:))
  }
  
  @inlinable
  public func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, TaskResult<V>>,
    onFail: OnFailAction<State, Action>? = nil,
    onSuccess setAction: @escaping (inout State, V) -> Void
  ) -> _ReceiveReducer<Self, TaskResult<V>> {
    self.onReceive(action: toReceiveAction) { state, result in
      switch result {
      case let .failure(error):
        if let onFail {
          return onFail(state: &state, error: error)
        }
        return .none
      case let .success(value):
        setAction(&state, value)
        return .none
      }
    }
  }
  
  @inlinable
  public func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, TaskResult<V>>,
    set toStateKeyPath: WritableKeyPath<State, V>,
    onFail: OnFailAction<State, Action>? = nil
  ) -> _ReceiveReducer<Self, TaskResult<V>> {
    self.onReceive(action: toReceiveAction) { state, result in
      switch result {
      case let .failure(error):
        if let onFail {
          return onFail(state: &state, error: error)
        }
        return .none
      case let .success(value):
        toStateKeyPath(root: &state, value: value)
        return .none
      }
    }
  }
  
  @inlinable
  public func onReceive<V>(
    action toReceiveAction: CaseKeyPath<Action, TaskResult<V>>,
    set toStateKeyPath: WritableKeyPath<State, V?>,
    onFail: OnFailAction<State, Action>? = nil
  ) -> _ReceiveReducer<Self, TaskResult<V>> {
    self.onReceive(action: toReceiveAction) { state, result in
      switch result {
      case let .failure(error):
        if let onFail {
          return onFail(state: &state, error: error)
        }
        return .none
      case let .success(value):
        toStateKeyPath(root: &state, value: value)
        return .none
      }
    }
  }
}

public enum OnFailAction<State, Action> {
  case fail(prefix: String? = nil, log: ((String) -> Void)? = nil)
  case handle((inout State, Error) -> Void)
 
  @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
  @inlinable
  static func fail(prefix: String? = nil, logger: Logger) -> Self {
    .fail(prefix: prefix, log: { logger.error("\($0)") })
  } 

  @usableFromInline
  func callAsFunction(state: inout State, error: Error) -> Effect<Action> {
    switch self {
    case let .fail(prefix, log):
      if let prefix {
        return .fail(prefix: prefix, error: error, log: log)
      } else {
        return .fail(error: error, log: log)
      }
    case let .handle(handler):
      handler(&state, error)
      return .none
    }
  }

}

extension WritableKeyPath {

  @usableFromInline
  func callAsFunction(root: inout Root, value: Value) {
    root[keyPath: self] = value
  }
  
}

public struct _ReceiveReducer<Parent: Reducer, Value>: Reducer {
  
  @usableFromInline
  let parent: Parent
  
  @usableFromInline
  let receiveAction: (Parent.Action) -> Value?

  @usableFromInline
  let setAction: (inout Parent.State, Value) -> Effect<Parent.Action>

  @usableFromInline
  init(
    parent: Parent,
    receiveAction: @escaping (Parent.Action) -> Value?,
    setAction: @escaping (inout Parent.State, Value) -> Effect<Parent.Action>
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
    var setEffects = Effect<Action>.none

    if let value = receiveAction(action) {
      setEffects = setAction(&state, value)
    }
    
    return .merge(baseEffects, setEffects)
  }
}

public struct _OnRecieveReducer<Parent: Reducer, TriggerAction, Value>: Reducer {

  @usableFromInline
  let parent: Parent

  @usableFromInline
  let triggerAction: (Parent.Action) -> TriggerAction?

  @usableFromInline
  let toReceiveAction: (TaskResult<Value>) -> Parent.Action

  @usableFromInline
  let resultHandler: () async throws -> Value

  @usableFromInline
  init(
    parent: Parent,
    triggerAction: @escaping (Parent.Action) -> TriggerAction?,
    toReceiveAction: @escaping (TaskResult<Value>) -> Parent.Action,
    resultHandler: @escaping () -> Value
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
      .run { send in
        await send(toReceiveAction(
          TaskResult { try await resultHandler() }
        ))
      }
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
