import Foundation
import SwiftUI

@MainActor
public protocol CacheProtocol<API>: Sendable {
    associatedtype API: APIProtocol
    
    var api: API { get }
    
    var cachedModels: [UUID: any ModelProtocol] { get }
    var cachedFailures: [UUID: Error] { get }
    var listFailures: [CacheListRequestSignature: Error] { get }
    
    func get<Request: APIListRequest>(_ request: Request) -> CacheEntry<[UUID: Request.Model], Request.Failure> where Request.API == API
    func get<Request: APIFindRequest>(_ request: Request) -> CacheEntry<Request.Model?, Request.Failure> where Request.API == API
    
    @discardableResult
    func execute<Request: APIListRequest>(request: Request) async throws(API.APIError) -> Result<[Request.Model], Request.Failure> where Request.API == API
    
    @discardableResult
    func execute<Request: APIFindRequest>(request: Request) async throws(API.APIError) -> Result<Request.Model, Request.Failure> where Request.API == API
}

public struct CacheListRequestSignature: Sendable, Hashable {
    var modelType: any (ModelProtocol.Type)
    var failureType: any (Error.Type)
    var filterOptions: any Hashable & Sendable
    
    init(modelType: any (ModelProtocol.Type), failureType: any (Error.Type), filterOptions: any Hashable & Sendable) {
        self.modelType = modelType
        self.failureType = failureType
        self.filterOptions = filterOptions
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(modelType.scheme)
        hasher.combine(filterOptions)
    }
    
    public static func == (lhs: CacheListRequestSignature, rhs: CacheListRequestSignature) -> Bool {
        lhs.modelType == rhs.modelType &&
        lhs.failureType == rhs.failureType &&
        lhs.filterOptions.hashValue == rhs.filterOptions.hashValue
    }
}

extension APIListRequest {
    var cacheSignature: CacheListRequestSignature {
        .init(modelType: Self.Model.self, failureType: Self.Failure.self, filterOptions: self.filterOptions)
    }
}

public struct CacheEntry<Value: Sendable, Failure: Sendable>: Sendable {
    public var value: Value
    public var failure: Failure?
    public var loading: Bool
    
    public init(value: Value, failure: Failure?, loading: Bool) {
        self.value = value
        self.failure = failure
        self.loading = loading
    }
}

@MainActor
@Observable
public class Cache<API: APIProtocol>: CacheProtocol {
    public var api: API
    
    public var cachedModels: [UUID: any ModelProtocol] = [:]
    public var cachedFailures: [UUID: Error] = [:]
    public var listFailures: [CacheListRequestSignature: Error] = [:]
    
    internal var listOperations: [CacheListRequestSignature: ListOperation] = [:]
    internal var findOperations: [UUID: FindOperation] = [:]
    
    public init(api: API) {
        self.api = api
    }
    
    public func get<Request: APIListRequest>(_ request: Request) -> CacheEntry<[UUID: Request.Model], Request.Failure> {
        let values = cachedModels
            .compactMapValues { $0 as? Request.Model }
            .filter { request.filterModel($0.value) }
        
        let failure = listFailures[request.cacheSignature] as? Request.Failure
        let runningOperation = listOperations[request.cacheSignature]
        return .init(value: values, failure: failure, loading: runningOperation != nil)
    }
    
    public func get<Request: APIFindRequest>(_ request: Request) -> CacheEntry<Request.Model?, Request.Failure> {
        let values = cachedModels[request.id] as? Request.Model
        let failure = cachedFailures[request.id] as? Request.Failure
        let runningOperation = findOperations[request.id]
        return .init(value: values, failure: failure, loading: runningOperation != nil)
    }
}

extension Cache {
    struct Operation<Value: Sendable, Failure: Error>: Equatable, Identifiable {
        var id = UUID()
        var task: Task<Result<Result<Value, Failure>, API.APIError>, Never>
        
        init<OperationRequest: APIRequest>(_ request: OperationRequest,
                                               on api: API,
                                               handleValue: @escaping @MainActor (OperationRequest.Response) -> Value,
                                               handleFailure: @escaping @MainActor (OperationRequest.Failure) -> Failure,
                                               handleAPIError: @escaping @MainActor (API.APIError) -> Void
        ) where OperationRequest.API == API {
            task = Task { @MainActor in
                do throws(API.APIError) {
                    let result = try await request.run(on: api)
                        .map(handleValue)
                        .mapError(handleFailure)
                    
                    return .success(result)
                } catch {
                    handleAPIError(error)
                    return .failure(error)
                }
            }
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
        
        func get() async throws(API.APIError) -> Result<Value, Failure> {
            try await task.value.get()
        }
    }
    
    typealias ListOperation = Operation<[any ModelProtocol], Error>
    typealias FindOperation = Operation<any ModelProtocol, Error>
    
    @discardableResult
    public func execute<Request: APIListRequest>(request: Request) async throws(API.APIError) -> Result<[Request.Model], Request.Failure> where Request.API == API {
        let runningOperation = listOperations[request.cacheSignature]
        let operation = runningOperation ?? ListOperation(request, on: api) { codingContainers in
            self.listFailures.removeValue(forKey: request.cacheSignature)
            
            let tuples = codingContainers.map { ($0.id, $0.properties) }
            let containers: [UUID: Request.Model.Properties] = .init(uniqueKeysWithValues: tuples)
            
            // remove everything from cachedValues that was apparently deleted
            let existingModels = self.cachedModels
                .compactMapValues { $0 as? Request.Model }
                .filter { request.filterModel($0.value) }
            for (id, _) in existingModels {
                if containers[id] == nil {
                    self.cachedModels.removeValue(forKey: id)
                    self.cachedFailures.removeValue(forKey: id)
                }
            }
            
            return containers.map { (id, properties) in
                // apply addidions/changes to cache
                self.cachedFailures.removeValue(forKey: id)
                if let model = self.cachedModels[id] as? Request.Model {
                    model.properties = properties
                    model.lastUpdated = .now
                    return model
                } else {
                    let model = Request.Model(id: id, properties: properties, cache: self)
                    self.cachedModels[id] = model
                    return model
                }
            }
        } handleFailure: { listFailure in
            self.listFailures[request.cacheSignature] = listFailure
            return listFailure
        } handleAPIError: { _ in
            self.listFailures.removeValue(forKey: request.cacheSignature)
        }
        
        listOperations[request.cacheSignature] = operation
        
        defer {
            // release the operation if it hasn't been done yet
            if listOperations[request.cacheSignature] == operation {
                listOperations.removeValue(forKey: request.cacheSignature)
            }
        }
        
        return try await operation.get()
            .map { $0.map { $0 as! Request.Model } }
            .mapError { $0 as! Request.Failure }
    }
    
    @discardableResult
    public func execute<Request: APIFindRequest>(request: Request) async throws(API.APIError) -> Result<Request.Model, Request.Failure> where Request.API == API {
        let runningOperation = findOperations[request.id]
        let operation = runningOperation ?? FindOperation(request, on: api) { codingContainer in
            self.cachedFailures.removeValue(forKey: request.id)
            
            if let model = self.cachedModels[request.id] as? Request.Model {
                model.properties = codingContainer.properties
                model.lastUpdated = .now
                return model
            } else {
                let model = Request.Model(id: codingContainer.id, properties: codingContainer.properties, cache: self)
                self.cachedModels[request.id] = model
                return model
            }
        } handleFailure: { findFailure in
            self.cachedFailures[request.id] = findFailure
            return findFailure
        } handleAPIError: { _ in
            self.cachedFailures.removeValue(forKey: request.id)
        }
        
        findOperations[request.id] = operation
        
        defer {
            // release the operation if it hasn't been done yet
            if findOperations[request.id] == operation {
                findOperations.removeValue(forKey: request.id)
            }
        }
        
        return try await operation.get()
            .map { $0 as! Request.Model }
            .mapError { $0 as! Request.Failure }
    }
}
