import ComposableArchitecture
import Foundation

/// A reducer that can handle `receive` actions when the action type implements the ``ReceiveAction`` protocol.
///
/// This allows you to handle the `success` and `failure` cases.
///
/// ## Example
/// ```swift
/// @Reducer
/// struct MyFeature {
///   ...
///   enum Action: ReceiveAction {
///     case receive(TaskResult<ReceiveAction>)
///
///     @CasePathable
///     enum ReceiveAction {
///       case numberFact(String)
///     }
///
///     ...
///   }
///
///   @Dependency(\.logger) var logger
///
///   public var body: some ReducerOf<Self> {
///     ReceiveReducer { state, action in
///       // Handle the success cases by switching on the receive action.
///       switch action {
///       case let .numberFact(fact):
///         state.numberFact = fact
///         return .none
///       }
///     }
///     .onFail(.log(logger: logger))
///
///     ...
///   }
///
public struct ReceiveReducer<State, Action: ReceiveAction>: Reducer {

  @usableFromInline
  let toResult: (Action) -> TaskResult<Action.ReceiveAction>?

  @usableFromInline
  let onSuccess: (inout State, Action.ReceiveAction) -> Effect<Action>

  @usableFromInline
  init(
    internal toResult: @escaping (Action) -> TaskResult<Action.ReceiveAction>?,
    onSuccess: @escaping(inout State, Action.ReceiveAction) -> Effect<Action>
  ) {
    self.toResult = toResult
    self.onSuccess = onSuccess
  }

  @inlinable
  public init(
    onSuccess: @escaping (inout State, Action.ReceiveAction) -> Effect<Action>
  ) {
    self.init(
      internal: {
        AnyCasePath(unsafe: Action.receive).extract(from: $0)
      },
      onSuccess: onSuccess
    )
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action> {
    guard let result = toResult(action) else { return .none }
    switch result {
    case .failure:
      return .none
    case let .success(value):
      return onSuccess(&state, value)
    }
  }

}
