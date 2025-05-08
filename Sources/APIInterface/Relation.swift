import Foundation

@propertyWrapper
public struct Relation<Parent: ModelProtocol, Request: APIFindRequest>: Sendable {
    public var parent: Parent?
    public var request: @MainActor (Parent) -> Request
    public var cache: (any CacheProtocol<Request.API>)?
    
    public init(parent: Parent? = nil, request: @escaping @MainActor (Parent) -> Request, cache: (any CacheProtocol<Request.API>)? = nil) {
        self.parent = parent
        self.request = request
        self.cache = cache
    }
    
    @MainActor
    public var wrappedValue: Request.Model? {
        guard let parent = parent else { return nil }
        return cache?.get(request(parent)).value
    }
    
    @MainActor
    public var isLoading: Bool {
        guard let parent = parent else { return false }
        return cache?.get(request(parent)).loading ?? false
    }
    
    @MainActor
    public var failure: Request.Failure? {
        guard let parent = parent else { return nil }
        return cache?.get(request(parent)).failure
    }
    
    public var projectedValue: Self { self }
}
