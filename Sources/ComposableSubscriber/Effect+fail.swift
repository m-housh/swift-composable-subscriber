import ComposableArchitecture
import OSLog

extension Effect {

  /// An effect that throws a runtime warning and optionally logs an error message.
  @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
  public static func fail(
    _ message: String,
    logger: Logger? = nil
  ) -> Self {
    XCTFail("\(message)")
    logger?.error("\(message)")
    return .none
  }

  /// An effect that throws a runtime warning and optionally logs an error message.
  @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
  public static func fail(
    prefix: String = "Failed error:",
    error: any Error,
    logger: Logger
  ) -> Self {
    return .fail(prefix: prefix, error: error, log: { logger.error("\($0)") })
  }

 /// An effect that throws a runtime warning and optionally logs an error message.
  public static func fail(
    prefix: String = "Failed error:",
    error: any Error,
    log: ((String) -> Void)? = nil
  ) -> Self {
    let message = "\(prefix) \(error.localizedDescription)"
    XCTFail("\(message)")
    log?("\(message)")
    return .none
  }



}
