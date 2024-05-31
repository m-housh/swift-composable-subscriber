import ComposableArchitecture
import Foundation

@usableFromInline
enum SetAction<State, Action, Value> {
  case operation(f: (inout State, Value) -> Effect<Action>)
  case keyPath(WritableKeyPath<State, Value>, effect: Effect<Action>)
  case optionalKeyPath(WritableKeyPath<State, Value?>, effect: Effect<Action>)

  @usableFromInline
  func callAsFunction(state: inout State, value: Value) -> Effect<Action> {
    switch self {
    case let .operation(f: f):
      return f(&state, value)
    case let .keyPath(keyPath, effect):
      state[keyPath: keyPath] = value
      return effect
    case let .optionalKeyPath(keyPath, effect):
      state[keyPath: keyPath] = value
      return effect
    }
  }
  
  @usableFromInline
  static func operation(_ f: @escaping (inout State, Value) -> Void) -> Self {
    .operation(f: { state, value in
      f(&state, value)
      return .none
    })
  }
 
}

@usableFromInline
struct SetAction2<State, Action, Value> {
  let operation: @Sendable (inout State, Value) -> Void
  
  init(_ operation: @escaping @Sendable (inout State, Value) -> Void) {
    self.operation = operation
  }
  
  static func keyPath(
    _ keyPath: WritableKeyPath<State, Value>
  ) -> Self {
    .init({ state, value in
      state[keyPath: keyPath] = value
    })
  }
}
