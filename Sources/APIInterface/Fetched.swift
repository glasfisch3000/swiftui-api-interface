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
    
    /// The function used to decode a value/failure result from an API response.
    public var decodeResult: @Sendable (API.Response) -> Value
    
    @State private var cachedValue: Result<Value, API.APIError>? = nil
    @State private var loadingTask: Task<Value, Error>? = nil
    
    public init(api: API, request: API.Request, decodeResult: @escaping @Sendable (API.Response) -> Value) {
        self.api = api
        self.request = request
        self.decodeResult = decodeResult
    }
    
    /// The resulting value from the last load action, if any.
    public var wrappedValue: Value? {
        try? self.cachedValue?.get()
    }
    
    public var projectedValue: Self { self }
    
    /// The API error that occurred during the last load action, if any.
    public var apiError: API.APIError? {
        switch self.cachedValue {
        case nil: nil
        case .success(_): nil
        case .failure(let error): error
        }
    }
    
    /// Indicates whether the value is currently being loaded from source.
    public var isLoading: Bool {
        !(self.loadingTask?.isCancelled ?? true)
    }
    
    @Sendable
    private func loadValue() async throws(API.APIError) -> Value {
        let response = try await api.makeRequest(self.request)
        return self.decodeResult(response)
    }
    
    /// Re-load the cached value.
    /// - Parameter force: Cancel any running load action and force a new one.
    /// - Throws: This function should never actually throw, although the compiler doesn't see it. You should be safe to discard any errors thrown from here.
    public func reload(force: Bool = false) async throws {
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
        
        let task = Task<Value, Error>(operation: self.loadValue)
        self.loadingTask = task
        
        switch await task.result {
        case .success(let result):
            self.cachedValue = .success(result)
        case .failure(let error as API.APIError):
            if error.shouldReport { await self.api.reportError(error) }
            self.cachedValue = .failure(error)
        case .failure(_ as CancellationError):
            // if the loading task is cancelled, leave the cached value as it is
            break
        case .failure(let error):
            // this shouldn't be possible!
            // anyway, errors are propagated so the caller can ignore them
            throw error
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
            let task = Task<Value, Error>(operation: self.loadValue)
            self.loadingTask = task
            
            switch await task.result {
            case .success(let result):
                self.cachedValue = .success(result)
            case .failure(let error as API.APIError):
                if error.shouldReport { await self.api.reportError(error) }
                self.cachedValue = .failure(error)
            case .failure(_ as CancellationError):
                // we ain't cancelling shit let's go again
                self.update()
            case .failure(let error):
                // this shouldn't be possible so we propagate the error so it can be immediately discarded
                throw error
            }
        }
    }
}
