import SwiftUI

/// A property wrapper, similar to SwiftUI's `State` or `Binding` types, that sources its value automatically from an API endpoint.
@MainActor
@propertyWrapper
public struct Fetched<Request: APIFindRequest>: Sendable, DynamicProperty {
    /// The cache that handles data loading.
    @State public var cache: any CacheProtocol<Request.API>
    
    /// The request to fetch the model with.
    public var request: Request
    
    @State private var alreadyFetched = false
    
    public init(request: Request, cache: any CacheProtocol<Request.API>) {
        self.request = request
        self.cache = cache
    }
    
    public var projectedValue: Self { self }
    
    /// The resulting value from the last load action, if any.
    public var wrappedValue: Request.Model? {
        cache.get(request).value
    }
    
    /// Indicates whether the value is currently being loaded from source.
    public var isLoading: Bool {
        cache.get(request).loading
    }
    
    /// The resulting failure from the last loading operation, if any.
    public var failure: Request.Failure? {
        cache.get(request).failure
    }
}

extension Fetched {
    /// Re-load the cached value.
    public func reload() async {
        defer { alreadyFetched = true }
        
        do {
            try await cache.execute(request: request)
        } catch { }
    }
    
    /// Inherited from `DynamicProperty.update()`.
    /// Do not use this manually as it is called automatically and has no effect once a value is cached.
    nonisolated
    public func update() {
        Task { @MainActor in
            if alreadyFetched { return }
            defer { alreadyFetched = true }
            
            guard cache.get(request).value == nil else { return }
            
            do {
                try await cache.execute(request: request)
            } catch { }
        }
    }
}
