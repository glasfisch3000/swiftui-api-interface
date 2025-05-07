import Foundation
import SwiftUI

@MainActor
public protocol CacheProtocol<Request>: Sendable {
    associatedtype API: APIProtocol
    associatedtype Model: ModelProtocol
    associatedtype Request: APIRequestSuite where Request.API == API, Request.Model == Model
    
    var api: API { get }
    var suite: Request { get }
    
    var cachedValues: [UUID: Model] { get }
    var listFailure: Request.List.Failure? { get }
    
    var isLoading: Bool { get }
    subscript(id: UUID) -> CacheEntry<Request.Find> { get }
    
    @discardableResult
    func load(request: Request.List?) async throws(API.APIError) -> Result<Void, Request.List.Failure>
    
    @discardableResult
    func fetch(id: UUID) async throws(API.APIError) -> Result<Model, Request.Find.Failure>
}

public struct CacheEntry<Request: APIFindRequest>: Sendable {
    public var value: Request.Model?
    public var failure: Request.Failure?
    public var loading: Bool
    
    public init(value: Request.Model? = nil, failure: Request.Failure? = nil, loading: Bool = false) {
        self.value = value
        self.failure = failure
        self.loading = loading
    }
}

@MainActor
@Observable
public class Cache<Request: APIRequestSuite>: CacheProtocol {
    public typealias API = Request.API
    public typealias Model = Request.Model
    
    public var api: API
    public var suite: Request
    
    public var cachedValues: [UUID: Model]
    public var listFailure: Request.List.Failure? = nil
    public var cachedFailures: [UUID: Request.Find.Failure] = [:]
    
    var listOperations: [Request.List.FilterOptions: ListOperation] = [:]
    var findOperations: [UUID: FindOperation] = [:]
    
    public init(api: API, requestSuite: Request) {
        self.api = api
        self.cachedValues = [:]
        self.suite = requestSuite
    }
    
    public var isLoading: Bool { listOperations.isEmpty }
    
    public subscript(id: UUID) -> CacheEntry<Request.Find> {
        .init(value: cachedValues[id], failure: cachedFailures[id], loading: findOperations[id] != nil)
    }
}

extension Cache {
    struct Operation<Value: Sendable, OperationRequest: APIRequest>: Equatable, Identifiable where OperationRequest.API == API {
        var id = UUID()
        var task: Task<Result<Result<Value, OperationRequest.Failure>, API.APIError>, Never>
        
        init(_ request: OperationRequest, on api: API, handler: @escaping @MainActor (OperationRequest.Response) -> Value) {
            task = Task { @MainActor in
                do throws(API.APIError) {
                    return .success(try await request.run(on: api).map(handler))
                } catch {
                    return .failure(error)
                }
            }
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
        
        func get() async throws(API.APIError) -> Result<Value, OperationRequest.Failure> {
            try await task.value.get()
        }
    }
    
    typealias ListOperation = Operation<Void, Request.List>
    typealias FindOperation = Operation<Model, Request.Find>
    
    @discardableResult
    public func load(request: Request.List? = nil) async throws(API.APIError) -> Result<Void, Request.List.Failure> {
        let listRequest = request ?? suite.list()
        let runningOperation = listOperations[listRequest.filterOptions]
        let operation = runningOperation ?? ListOperation(listRequest, on: api) { containers in
            let tuples = containers.map { ($0.id, $0.properties) }
            let containers: [UUID: Model.Properties] = .init(uniqueKeysWithValues: tuples)
            
            // remove everything from cachedValues that is not in containers
            for (id, _) in listRequest.filterModels(self.cachedValues) {
                if containers[id] == nil {
                    self.cachedValues.removeValue(forKey: id)
                    self.cachedFailures.removeValue(forKey: id)
                }
            }
            
            // apply addidions/changes to cachedValues
            for (id, properties) in containers {
                if let model = self.cachedValues[id] {
                    model.properties = properties
                    model.lastUpdated = .now
                } else {
                    self.cachedValues[id] = Model(id: id, properties: properties)
                }
                
                // remove all the cached find failures for the loaded models
                self.cachedFailures.removeValue(forKey: id)
            }
            
            return ()
        }
        listOperations[listRequest.filterOptions] = operation
        
        defer {
            // release the operation if it hasn't been done yet
            if listOperations[listRequest.filterOptions] == operation {
                listOperations.removeValue(forKey: listRequest.filterOptions)
            }
        }
        
        switch try await operation.get() {
        case .success(_): return .success(())
        case .failure(let failure):
            listFailure = failure
            return .failure(failure)
        }
    }
    
    @discardableResult
    public func fetch(id: UUID) async throws(API.APIError) -> Result<Model, Request.Find.Failure> {
        let operation = findOperations[id] ?? FindOperation(suite.find(id: id), on: api) { container in
            self.cachedFailures.removeValue(forKey: id)
            if let model = self.cachedValues[id] {
                model.properties = container.properties
                model.lastUpdated = .now
                return model
            } else {
                let model = Model(id: id, properties: container.properties)
                self.cachedValues[id] = model
                return model
            }
        }
        findOperations[id] = operation
        
        defer {
            // release the operation if it hasn't been done yet
            if findOperations[id] == operation {
                findOperations.removeValue(forKey: id)
            }
        }
        
        switch try await operation.get() {
        case .success(let model): return .success(model)
        case .failure(let failure):
            cachedFailures[id] = failure
            return .failure(failure)
        }
    }
}
