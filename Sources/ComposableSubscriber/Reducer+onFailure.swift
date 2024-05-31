import ComposableArchitecture
import Foundation
import OSLog

extension Reducer {

  @inlinable
  public func onFailure(
    case toError: CaseKeyPath<Action, Error>,
    _ onFail: OnFailureAction<State, Action>
  ) -> _OnFailureReducer<Self> {
    .init(
      parent: self,
      toError: .init(AnyCasePath(toError)),
      onFailAction: onFail
    )
  }

  @inlinable
  public func onFailure<T>(
    case toError: CaseKeyPath<Action, TaskResult<T>>,
    _ onFail: OnFailureAction<State, Action>
  ) -> _OnFailureReducer<Self> {
    .init(
      parent: self,
      toError: .init(AnyCasePath(toError)),
      onFailAction: onFail
    )
  }
}

extension Reducer where Action: ReceiveAction {

  @inlinable
  public func onFailure(
    _ onFail: OnFailureAction<State, Action>
  ) -> _OnFailureReducer<Self> {
    .init(
      parent: self,
      toError: .init(AnyCasePath(unsafe: Action.receive)),
      onFailAction: onFail)
  }
}

public struct OnFailureAction<State, Action>: Sendable {

  @usableFromInline
  let operation: @Sendable (inout State, Error) -> Effect<Action>

  @inlinable
  public init(_ operation: @escaping @Sendable (inout State, Error) -> Effect<Action>) {
    self.operation = operation
  }

  @inlinable
  public static func set(_ keyPath: WritableKeyPath<State, Error?>) -> Self {
    .init { state, error in
      state[keyPath: keyPath] = error
      return .none
    }
  }

  @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
  @inlinable
  public static func log(prefix: String? = nil, logger: Logger) -> Self {
    .fail(prefix: prefix, log: { logger.error("\($0)") })
  }

  @inlinable
  public static func fail(prefix: String? = nil, log: (@Sendable (String) -> Void)? = nil) -> Self {
    .init { _, error in
      guard let prefix else {
        return .fail(error: error, log: log)
      }
      return .fail(prefix: prefix, error: error, log: log)
    }
  }

  @usableFromInline
  func callAsFunction(state: inout State, error: Error) -> Effect<Action> {
    operation(&state, error)
  }
}

@usableFromInline
struct ToError<Action> {

  @usableFromInline
  let operation: (Action) -> Error?

  @usableFromInline
  init(_ casePath: AnyCasePath<Action, Error>) {
    self.operation = { casePath.extract(from: $0) }
  }

  @usableFromInline
  init<T>(_ result: AnyCasePath<Action, TaskResult<T>>) {
    self.operation = {
      let result = result.extract(from: $0)
      guard case let .failure(error) = result else { return nil }
      return error
    }
  }

}

public struct _OnFailureReducer<Parent: Reducer>: Reducer {

  @usableFromInline
  let parent: Parent

  @usableFromInline
  let toError: ToError<Parent.Action>

  @usableFromInline
  let onFailAction: OnFailureAction<Parent.State, Parent.Action>

  @usableFromInline
  init(
    parent: Parent,
    toError: ToError<Parent.Action>,
    onFailAction: OnFailureAction<Parent.State, Parent.Action>
  ) {
    self.parent = parent
    self.toError = toError
    self.onFailAction = onFailAction
  }

  public func reduce(
    into state: inout Parent.State,
    action: Parent.Action
  ) -> Effect<Parent.Action> {
    let baseEffects = parent.reduce(into: &state, action: action)

    guard let error = toError.operation(action) else {
      return baseEffects
    }

    return .merge(
      baseEffects,
      onFailAction(state: &state, error: error)
    )
  }
}
