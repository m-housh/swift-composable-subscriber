import ComposableArchitecture
import XCTest
@testable import ComposableSubscriber

@DependencyClient
struct NumberClient {
  var numberStreamWithoutArg: @Sendable () async -> AsyncStream<Int> = { .never }
  var numberStreamWithArg: @Sendable (Int) async -> AsyncStream<Int> = { _ in .never }
  var currentNumber: @Sendable () async throws -> Int

  func currentNumber(fail: Bool = false) async throws -> Int {
    if fail {
      throw CurrentNumberError()
    }
    return try await currentNumber()
  }

}

struct CurrentNumberError: Error { }

extension NumberClient: TestDependencyKey {
  
  static var live: NumberClient {
    NumberClient(
      numberStreamWithoutArg: {
        AsyncStream { continuation in
          continuation.yield(1)
          continuation.finish()
        }
      },
      numberStreamWithArg: { number in
        AsyncStream { continuation in
          continuation.yield(number)
          continuation.finish()
        }
      },
      currentNumber: { 69420 }
    )
  }
  
  static let testValue = Self()
}

extension DependencyValues {
  var numberClient: NumberClient {
    get { self[NumberClient.self] }
    set { self[NumberClient.self] = newValue }
  }
}

struct NumberState: Equatable {
  var number: Int
  var currentNumber: Int?
}

@CasePathable
enum NumberAction {
  case receive(Int)
  case task
}

@Reducer
struct ReducerWithArg {

  typealias State = NumberState
  typealias Action = NumberAction
  
  @Dependency(\.numberClient) var numberClient
  
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .receive(currentNumber):
        state.currentNumber = currentNumber
        return .none

      case .task:
        return .none
      }
    }
    .subscribe(
      to: numberClient.numberStreamWithArg,
      using: \.number,
      on: \.task,
      with: \.receive
    )
  }
}

@Reducer
struct ReducerWithTransform {

  typealias State = NumberState
  typealias Action = NumberAction

  @Dependency(\.numberClient) var numberClient

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .receive(currentNumber):
        state.currentNumber = currentNumber
        return .none

      case .task:
        return .none
      }
    }
    .subscribe(
      to: numberClient.numberStreamWithArg,
      using: \.number,
      on: \.task,
      with: \.receive
    ) {
      $0 * 2
    }
  }
}

@Reducer
struct ReducerWithReceiveAction {
  typealias State = NumberState

  enum Action: ReceiveAction {

    case receive(TaskResult<ReceiveAction>)
    case task

    @CasePathable
    enum ReceiveAction {
      case currentNumber(Int)
    }
  }

  @Dependency(\.numberClient) var numberClient

  public var body: some Reducer<State, Action> {
    ReceiveReducer(onFail: .fail()) { state, action in
      switch action {
      case let .currentNumber(number):
        state.currentNumber = number
        return .none
      }
    }
    .receive(on: \.task, case: \.currentNumber) {
      try await numberClient.currentNumber()
    }
  }

}

@Reducer
struct FailingReducer {

  struct State: Equatable {
    static func == (lhs: FailingReducer.State, rhs: FailingReducer.State) -> Bool {
      lhs.error?.localizedDescription == rhs.error?.localizedDescription
    }
    
    var error: Error?
  }

  enum Action: ReceiveAction {

    case receive(TaskResult<ReceiveAction>)
    case task

    @CasePathable
    enum ReceiveAction {
      case currentNumber(Int)
    }
  }

  @Dependency(\.numberClient) var numberClient

  public var body: some Reducer<State, Action> {
    ReceiveReducer(onFail: .set(keyPath: \.error)) { state, action in
      switch action {
      case .currentNumber(_):
        return .none
      }
    }
    .receive(on: \.task, case: \.currentNumber) {
      try await numberClient.currentNumber(fail: true)
    }
  }

}

final class TCAExtrasTests: XCTestCase {

  @MainActor
  func testSubscribeWithArg() async throws {
    let store = TestStore(
      initialState: ReducerWithArg.State(number: 19),
      reducer: ReducerWithArg.init
    ) {
      $0.numberClient = .live
    }
    
    let task = await store.send(.task)
    await store.receive(\.receive) {
      $0.currentNumber = 19
    }
    
    await task.cancel()
    await store.finish()
  }
  
  @MainActor
  func testSubscribeWithArgAndTransform() async throws {
    let store = TestStore(
      initialState: ReducerWithTransform.State(number: 10),
      reducer: ReducerWithTransform.init
    ) {
      $0.numberClient = .live
    }
    
    let task = await store.send(.task)
    await store.receive(\.receive) {
      $0.currentNumber = 20
    }
    
    await task.cancel()
    await store.finish()
  }

  @MainActor
  func testReceiveAction() async throws {
    let store = TestStore(
      initialState: ReducerWithReceiveAction.State(number: 19),
      reducer: ReducerWithReceiveAction.init
    ) {
      $0.numberClient = .live
    }

    let task = await store.send(.task)
    await store.receive(\.receive.success.currentNumber) {
      $0.currentNumber = 69420
    }

    await task.cancel()
    await store.finish()
  }
  
  @MainActor
  func testFailEffect() async throws {

    let store = TestStore(
      initialState: FailingReducer.State(),
      reducer: FailingReducer.init
    ) {
      $0.numberClient = .live
    }

    let task = await store.send(.task)
    await store.receive(\.receive.failure) {
      $0.error = CurrentNumberError()
    }

    await task.cancel()
    await store.finish()
  }


}
