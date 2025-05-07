import SwiftUI

/// A property wrapper, similar to SwiftUI's `State` or `Binding` types, that sources its values automatically from an API endpoint.
@MainActor
@propertyWrapper
public struct ListFetched<Cache: CacheProtocol, ListRequest: APIListRequest>: Sendable, DynamicProperty where ListRequest.API == Cache.API, ListRequest.Model == Cache.Model {
    /// The cache that handles data loading.
    @State public var cache: Cache
    @State public var request: ListRequest?
    
    public init(cache: Cache, request: ListRequest? = nil, requestType: ListRequest.Type = ListRequest.self) {
        self.cache = cache
        self.request = request
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
        do {
            if let request = self.request, ListRequest.self != Cache.Request.List.self {
                try await cache.execute(listRequest: request)
            } else {
                try await cache.load()
            }
        } catch { }
    }
    
    /// Inherited from `DynamicProperty.update()`.
    /// Do not use this manually as it is called automatically and has no effect once a value is cached.
    nonisolated
    public func update() {
        Task { @MainActor in
            let values = if let request = request {
                request.filterModels(cache.cachedValues)
            } else {
                cache.cachedValues
            }
            guard values.isEmpty else { return }
            
            do {
                if let request = self.request, ListRequest.self != Cache.Request.List.self {
                    try await cache.execute(listRequest: request)
                } else {
                    try await cache.load()
                }
            } catch { }
        }
    }
}
