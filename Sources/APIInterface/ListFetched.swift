import SwiftUI

/// A property wrapper, similar to SwiftUI's `State` or `Binding` types, that sources its values automatically from an API endpoint.
@MainActor
@propertyWrapper
public struct ListFetched<Cache: CacheProtocol>: Sendable, DynamicProperty {
    /// The cache that handles data loading.
    @State public var cache: Cache
    @State public var request: Cache.Request.List?
    
    @State private var alreadyFetched = false
    
    public init(cache: Cache, request: Cache.Request.List? = nil) {
        self.cache = cache
        self._request = .init(initialValue: request)
    }
    
    /// The resulting value from the last load action, if any.
    public var wrappedValue: [UUID: Cache.Model]? {
        if let request = request {
            request.filterModels(cache.cachedValues)
        } else {
            cache.cachedValues
        }
    }
    
    /// Indicates whether the value is currently being loaded from source.
    public var isLoading: Bool {
        cache.isLoading
    }
    
    /// The resulting failure from the last loading operation, if any.
    public var failure: Cache.Request.List.Failure? {
        cache.listFailure
    }
}

extension ListFetched {
    /// Re-load the cached value.
    public func reload() async {
        defer {
            alreadyFetched = true
        }
        
        do {
            try await cache.load(request: request)
        } catch { }
    }
    
    /// Inherited from `DynamicProperty.update()`.
    /// Do not use this manually as it is called automatically and has no effect once a value is cached.
    nonisolated
    public func update() {
        Task { @MainActor in
            if alreadyFetched { return }
            defer { alreadyFetched = true }
            
            let values = if let request = request {
                request.filterModels(cache.cachedValues)
            } else {
                cache.cachedValues
            }
            guard values.isEmpty else { return }
            
            do {
                try await cache.load(request: request)
            } catch { }
        }
    }
}
