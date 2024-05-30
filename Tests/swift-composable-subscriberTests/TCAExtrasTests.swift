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
      struct CurrentNumberError: Error { }
      throw CurrentNumberError()
    }
    return try await currentNumber()
  }

}

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

    EmptyReducer()
      .onReceive(action: \.receive, set: \.currentNumber)
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
    EmptyReducer()
      .onReceive(action: \.receive, set: \.currentNumber)
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
    .receive(on: \.task, with: \.currentNumber) {
      try await numberClient.currentNumber()
    }

//    Reduce<State, Action> { state, action in
//      switch action {
//
//      case .receive:
//        return .none
//
//      case .task:
//        return .receive(\.currentNumber) {
//          try await numberClient.currentNumber()
//        }
//      }
//    }
  }

}

@MainActor
final class TCAExtrasTests: XCTestCase {

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

  func testReceiveAction() async throws {
    let store = TestStore(
      initialState: ReducerWithReceiveAction.State(number: 19),
      reducer: ReducerWithReceiveAction.init
    ) {
      $0.numberClient = .live
    }

    let task = await store.send(.task)
    await store.receive(\.receive) {
      $0.currentNumber = 69420
    }

    await task.cancel()
    await store.finish()
  }

}
