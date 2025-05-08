import Foundation

@propertyWrapper
public struct Relation<Request: APIFindRequest>: Sendable {
    public var request: @MainActor () -> Request
    public var cache: any CacheProtocol<Request.API>
    
    public init(request: @escaping @MainActor () -> Request, cache: any CacheProtocol<Request.API>) {
        self.request = request
        self.cache = cache
    }
    
    @MainActor
    public var wrappedValue: Request.Model? {
        cache.get(request()).value
    }
    
    @MainActor
    public var isLoading: Bool {
        cache.get(request()).loading
    }
    
    @MainActor
    public var failure: Request.Failure? {
        cache.get(request()).failure
    }
    
    public var projectedValue: Self { self }
}
