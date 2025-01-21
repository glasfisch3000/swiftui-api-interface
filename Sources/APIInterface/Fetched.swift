import SwiftUI

/// A property wrapper, similar to SwiftUI's `State` or `Binding` types, that sources its value automatically from an API endpoint.
///
/// > Note: `Fetched` uses `api.makeRequest(_:)` to load values.
/// > Any error thrown there will be reported to that API.
/// > However, this is intended only for global errors, like connection problems or missing authentication.
/// > Once an API response is retrieved, any problems it causes should be handled separetely. If, for instance, decoding the response can produce errors, consider using a `Result` as `Value`.
@propertyWrapper
public struct Fetched<API: APIProtocol, Request: APIRequestProtocol>: Sendable, DynamicProperty where Request.API == API {
    /// The API endpoint to load data from.
    public var api: API
    
    /// The data used to request a result from the API.
    public var request: Request
    
    @State var cachedValue: Result<Request.Response, API.APIError>?
    @State var loadingTask: Task<Result<Request.Response, API.APIError>, Never>?
    
    public init(api: API, request: Request) {
        self.api = api
        self.request = request
    }
    
    /// A reference to the `Fetched` struct itself.
    @inlinable
    public var projectedValue: Self { self }
    
    /// The resulting value from the last load action, if any.
    public var wrappedValue: Request.Response? {
        try? cachedValue?.get()
    }
    
    /// The API error that occurred during the last load action, if any.
    public var apiError: API.APIError? {
        switch self.cachedValue {
        case .success(_): nil
        case .failure(let error): error
        case nil: nil
        }
    }
    
    /// Indicates whether the value is currently being loaded from source.
    public var isLoading: Bool {
        if let loadingTask = loadingTask {
            !loadingTask.isCancelled
        } else {
            false
        }
    }
}

extension Fetched {
    /// Re-load the cached value.
    /// - Parameter force: Cancel any running load action and force a new one.
    /// - Throws: This function should never actually throw, although the compiler doesn't see it. You should be safe to discard any errors thrown from here.
    public func reload(force: Bool = false) async {
        // check if a loading task is already running
        if let loadingTask = self.loadingTask {
            if force { // if set to force reload, kill the running task
                loadingTask.cancel()
                self.loadingTask = nil
            } else if loadingTask.isCancelled { // if the loading task isn't running any more, remove it
                self.loadingTask = nil
            } else {
                return
            }
        }
        
        // make a new loading task
        let task = Task<Result<Request.Response, API.APIError>, Never> {
            do throws(API.APIError) {
                return .success(try await request.run(on: api))
            } catch {
                return .failure(error)
            }
        }
        self.loadingTask = task
        
        self.cachedValue = await task.value
        if self.loadingTask == task { self.loadingTask = nil }
    }
    
    /// Inherited from `DynamicProperty.update()`.
    /// Do not use this manually as it is called automatically and has no effect once a value is cached.
    public func update() {
        guard self.cachedValue == nil else { return }
        
        Task {
            await reload()
        }
    }
}
