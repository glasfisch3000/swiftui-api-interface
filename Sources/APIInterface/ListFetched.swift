import SwiftUI

/// A property wrapper, similar to SwiftUI's `State` or `Binding` types, that sources its values automatically from an API endpoint.
@MainActor
@propertyWrapper
public struct ListFetched<Request: APIListRequest>: Sendable, DynamicProperty {
    /// The cache that handles data loading.
    @State public var cache: any CacheProtocol<Request.API>
    
    /// The request to fetch the models with.
    public var request: Request
    
    public init(request: Request, cache: any CacheProtocol<Request.API>) {
        self.request = request
        self.cache = cache
    }
    
    public var projectedValue: Self { self }
    
    /// The resulting value from the last load action, if any.
    public var wrappedValue: [UUID: Request.Model]? {
        cache.get(request)?.value
    }
    
    /// Indicates whether the value is currently being loaded from source.
    public var isLoading: Bool {
        cache.get(request)?.loading ?? false
    }
    
    /// The resulting failure from the last loading operation, if any.
    public var failure: Request.Failure? {
        cache.get(request)?.failure
    }
}

extension ListFetched {
    /// Re-load the cached value.
	@Sendable
    public func reload() async {
        do {
            try await cache.execute(request: request)
        } catch { }
    }
    
    /// Inherited from `DynamicProperty.update()`.
    /// Do not use this manually as it is called automatically and has no effect once a value is cached.
	@Sendable
    nonisolated
    public func update() {
        Task { @MainActor in
            guard cache.get(request) == nil else { return }
            
            do {
                try await cache.execute(request: request)
            } catch { }
        }
    }
}
