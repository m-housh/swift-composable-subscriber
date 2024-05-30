import ComposableArchitecture
import Foundation
import OSLog

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
