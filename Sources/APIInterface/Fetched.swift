import SwiftUI

/// A property wrapper, similar to SwiftUI's `State` or `Binding` types, that sources its value automatically from an API endpoint.
///
/// > Note: `Fetched` uses `api.makeRequest(_:)` to load values.
/// > Any error thrown there will be reported to that API.
/// > However, this is intended only for global errors, like connection problems or missing authentication.
/// > Once an API response is retrieved, any problems it causes should be handled separetely. If, for instance, decoding the response can produce errors, consider using a `Result` as `Value`.
@propertyWrapper
public struct Fetched<API, Value>: Sendable, DynamicProperty where API: APIProtocol, Value: Sendable {
    /// The API endpoint to load data from.
    public var api: API
    
    /// The data used to request a result from the API.
    public var request: API.Request
    
    /// This function is used to request a new value from the api, using the supplied API endpoint and request value.
    /// - Throws: An instance of `API.APIError`, if any.
    public var fetchValue: @Sendable (API, API.Request) async throws(API.APIError) -> Value
    
    @State public var cachedValue: Result<Value, API.APIError>?
    @State public var loadingTask: Task<Result<Value, API.APIError>, Never>?
    
    public init(api: API, request: API.Request, fetchValue: @Sendable @escaping (API, API.Request) async throws(API.APIError) -> Value) {
        self.api = api
        self.request = request
        self.fetchValue = fetchValue
    }
    
    /// A reference to the `Fetched` struct itself.
    @inlinable
    public var projectedValue: Self { self }
    
    /// The resulting value from the last load action, if any.
    @inlinable
    public var wrappedValue: Value? {
        try? self.cachedValue?.get()
    }
    
    /// The API error that occurred during the last load action, if any.
    @inlinable
    public var apiError: API.APIError? {
        switch self.cachedValue {
        case nil: nil
        case .success(_): nil
        case .failure(let error): error
        }
    }
    
    /// Indicates whether the value is currently being loaded from source.
    @inlinable
    public var isLoading: Bool {
        !(self.loadingTask?.isCancelled ?? true)
    }
}

extension Fetched {
    /// Re-load the cached value.
    /// - Parameter force: Cancel any running load action and force a new one.
    /// - Throws: This function should never actually throw, although the compiler doesn't see it. You should be safe to discard any errors thrown from here.
    public func reload(force: Bool = false) async {
        if let loadingTask = self.loadingTask {
            if force {
                loadingTask.cancel()
                self.loadingTask = nil
            } else if loadingTask.isCancelled {
                self.loadingTask = nil
            } else {
                return
            }
        }
        
        let task = Task<Result<Value, API.APIError>, Never> {
            do throws(API.APIError) {
                return .success(try await self.fetchValue(api, request))
            } catch {
                return .failure(error)
            }
        }
        self.loadingTask = task
        
        let value = await task.value
        if self.loadingTask == task { self.loadingTask = nil }
        
        switch value {
        case .success(let value):
            self.cachedValue = .success(value)
        case .failure(let apiError):
            if apiError.shouldReport { await self.api.reportError(apiError) }
            self.cachedValue = .failure(apiError)
        }
    }
    
    /// Inherited from `DynamicProperty.update()`.
    /// Do not use this manually as it is called automatically and has no effect once a value is cached.
    public func update() {
        if let loadingTask = self.loadingTask {
            guard loadingTask.isCancelled else { return }
            self.loadingTask = nil
        }
        
        guard self.cachedValue == nil else { return }
        
        Task {
            let task = Task<Result<Value, API.APIError>, Never> {
                do throws(API.APIError) {
                    return .success(try await self.fetchValue(api, request))
                } catch {
                    return .failure(error)
                }
            }
            self.loadingTask = task
            
            let value = await task.value
            if self.loadingTask == task { self.loadingTask = nil }
            
            switch value {
            case .success(let value):
                self.cachedValue = .success(value)
            case .failure(let apiError):
                if apiError.shouldReport { await self.api.reportError(apiError) }
                self.cachedValue = .failure(apiError)
            }
        }
    }
}
