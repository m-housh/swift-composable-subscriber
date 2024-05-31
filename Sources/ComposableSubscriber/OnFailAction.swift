import ComposableArchitecture
import Foundation
import OSLog

/// Handle failures, generally used with actions that accept a task result.
///
/// This is used in some of the higher order reducers to describe how they should handle failures.
public enum OnFailAction<State, Action> {

  /// Throw a runtime warning and optionally log the error.
  case fail(prefix: String? = nil, log: (@Sendable (String) -> Void)? = nil)

  /// Ignore the error.
  case ignore

  /// Handle the error, generally used to set the error on your state.
  case operation((inout State, Error) -> Effect<Action>)

  @usableFromInline
  func callAsFunction(state: inout State, error: Error) -> Effect<Action> {
    switch self {
    case .ignore:
      return .none
    case let .fail(prefix, log):
      if let prefix {
        return .fail(prefix: prefix, error: error, log: log)
      } else {
        return .fail(error: error, log: log)
      }
    case let .operation(handler):
      return handler(&state, error)

    }
  }
 
  @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
  @inlinable
  static func fail(prefix: String? = nil, logger: Logger) -> Self {
    .fail(prefix: prefix, log: { logger.error("\($0)") })
  }

  @inlinable
  public static func set(
    _ operation: @escaping @Sendable (inout State, Error) -> Void
  ) -> Self {
    .operation(
      SetAction.operation(operation).callAsFunction(state:value:)
    )
  }
  
  @inlinable
  public static func set(
    _ operation: @escaping @Sendable (inout State, Error) -> Effect<Action>
  ) -> Self {
    .operation(
      SetAction.operation(f: operation).callAsFunction(state:value:)
    )
  }
  
  @inlinable
  public static func set(
    keyPath: WritableKeyPath<State, Error?>,
    effect: Effect<Action> = .none
  ) -> Self {
    .operation(
      SetAction.optionalKeyPath(
        keyPath,
        effect: effect
      ).callAsFunction(state:value:)
    )
  }
}
