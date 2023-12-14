import ComposableArchitecture

extension Reducer {
	public func subscribe<TriggerAction, StreamElement>(
		to stream: @escaping () async -> AsyncStream<StreamElement>,
		on triggerAction: CaseKeyPath<Action, TriggerAction>,
		with responseAction: CaseKeyPath<Action, StreamElement>
	) -> _SubscribeReducer<Self, TriggerAction, StreamElement, StreamElement> {
		.init(
			parent: self,
			on: triggerAction,
			to: stream,
			with: responseAction,
			transform: { $0 }
		)
	}

	public func subscribe<TriggerAction, StreamElement, Value>(
		to stream: @escaping () async -> AsyncStream<StreamElement>,
		on triggerAction: CaseKeyPath<Action, TriggerAction>,
		with responseAction: CaseKeyPath<Action, Value>,
		transform: @escaping (StreamElement) -> Value
	) -> _SubscribeReducer<Self, TriggerAction, StreamElement, Value> {
		.init(
			parent: self,
			on: triggerAction,
			to: stream,
			with: responseAction,
			transform: transform
		)
	}
}

public struct _SubscribeReducer<Parent: Reducer, TriggerAction, StreamElement, Value>: Reducer {
	@usableFromInline
	let parent: Parent

	@usableFromInline
	let triggerAction: AnyCasePath<Parent.Action, TriggerAction>

	@usableFromInline
	let stream: () async -> AsyncStream<StreamElement>

	@usableFromInline
	let responseAction: AnyCasePath<Parent.Action, Value>

	@usableFromInline
	let transform: (StreamElement) -> Value

	init(
		parent: Parent,
		on triggerAction: CaseKeyPath<Parent.Action, TriggerAction>,
		to stream: @escaping () async -> AsyncStream<StreamElement>,
		with responseAction: CaseKeyPath<Parent.Action, Value>,
		transform: @escaping (StreamElement) -> Value
	) {
		self.parent = parent
		self.triggerAction = AnyCasePath(triggerAction)
		self.stream = stream
		self.responseAction = AnyCasePath(responseAction)
		self.transform = transform
	}

	public func reduce(into state: inout Parent.State, action: Parent.Action) -> Effect<Parent.Action> {
		let effects = parent.reduce(into: &state, action: action)

		guard self.triggerAction.extract(from: action) != nil else {
			return effects
		}

		return .merge(
			effects,
			.run { send in
				for await value in await stream() {
					await send(responseAction.embed(transform(value)))
				}
			}
		)
	}
}
