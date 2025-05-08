import SwiftUI

/// A property wrapper, similar to SwiftUI's `State` or `Binding` types, that sources its value automatically from an API endpoint.
@MainActor
@propertyWrapper
public struct Fetched<Cache: CacheProtocol>: Sendable, DynamicProperty {
    /// The cache that handles data loading.
    @State public var cache: Cache
    
    /// The ID of the model to fetch.
    @State public var modelID: UUID
    
    @State private var alreadyFetched = false
    
    public init(id: UUID, cache: Cache) {
        self.modelID = id
        self.cache = cache
    }
    
    /// The resulting value from the last load action, if any.
    public var wrappedValue: Cache.Model? {
        cache[modelID].value
    }
    
    /// Indicates whether the value is currently being loaded from source.
    public var isLoading: Bool {
        cache[modelID].loading
    }
    
    /// The resulting failure from the last loading operation, if any.
    public var failure: Cache.Request.Find.Failure? {
        cache[modelID].failure
    }
}

extension Fetched {
    /// Re-load the cached value.
    public func reload() async {
        defer { alreadyFetched = true }
        
        do {
            try await cache.fetch(id: modelID)
        } catch { }
    }
    
    /// Inherited from `DynamicProperty.update()`.
    /// Do not use this manually as it is called automatically and has no effect once a value is cached.
    nonisolated
    public func update() {
        Task { @MainActor in
            if alreadyFetched { return }
            defer { alreadyFetched = true }
            
            guard cache[modelID].value == nil else { return }
            
            do {
                try await cache.fetch(id: modelID)
            } catch { }
        }
    }
}
