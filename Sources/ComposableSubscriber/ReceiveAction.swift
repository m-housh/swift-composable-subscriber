import ComposableArchitecture

/// An action type that exposes a `receive` method that accepts task result, generally from
/// calling external dependencies.  
///
/// This allows for multiple receive actions to be nested under
/// one single action that handle the `failure` and `success` cases more conveniently
/// by using some of the higher order reducers provided by this package.
public protocol ReceiveAction<ReceiveAction> {

  /// The success cases.
  associatedtype ReceiveAction

  /// The root receive case that is used to handle the results.
  static func receive(_ result: TaskResult<ReceiveAction>) -> Self

}

