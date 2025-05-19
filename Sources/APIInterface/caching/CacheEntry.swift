public struct CacheEntry<Value: Sendable, Failure: Sendable>: Sendable {
	public var value: Value
	public var failure: Failure?
	public var loading: Bool
	
	public init(value: Value, failure: Failure?, loading: Bool) {
		self.value = value
		self.failure = failure
		self.loading = loading
	}
}
