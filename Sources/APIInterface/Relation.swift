import Foundation

@propertyWrapper
public struct Relation<Parent: ModelProtocol, Request: APIFindRequest>: Sendable {
    public var parent: Parent?
    public var request: @MainActor (Parent.Properties) -> Request
    public var cache: (any CacheProtocol<Request.API>)?
    
    public init(parent: Parent? = nil, request: @escaping @MainActor (Parent.Properties) -> Request, cache: (any CacheProtocol<Request.API>)? = nil) {
        self.parent = parent
        self.request = request
        self.cache = cache
    }
    
    public mutating func connect(parent: Parent, cache: any CacheProtocol<Request.API>) {
        self.parent = parent
        self.cache = cache
    }
    
    @MainActor
    public var wrappedValue: Request.Model? {
        guard let parent = parent else { return nil }
        return cache?.get(request(parent.properties))?.value
    }
    
    @MainActor
    public var isLoading: Bool {
        guard let parent = parent else { return false }
        return cache?.get(request(parent.properties))?.loading ?? false
    }
    
    @MainActor
    public var failure: Request.Failure? {
        guard let parent = parent else { return nil }
        return cache?.get(request(parent.properties))?.failure
    }
    
    public var projectedValue: Self { self }
}
