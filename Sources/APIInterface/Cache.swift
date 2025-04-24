import Foundation
import SwiftUI

@MainActor
@Observable
public class Cache<API: APIProtocol, Model: ModelProtocol, Request: APIRequestSuite<API, Model>> {
    public var api: API
    public var suite: Request
    
    public var cachedValues: [UUID: Model]
    public var listFailure: Request.List.Failure?
    
    var listOperation: ListOperation? = nil
    var findOperations: [UUID: FindOperation] = [:]
    
    public init(api: API, requestSuite: Request) {
        self.api = api
        self.cachedValues = [:]
        self.suite = requestSuite
    }
}

extension Cache {
    public struct Entry {
        public var value: Model?
        public var loading: Bool
        
        public init(value: Model? = nil, loading: Bool = false) {
            self.value = value
            self.loading = loading
        }
    }
    
    public var isLoading: Bool { listOperation != nil }
    
    public subscript(id: UUID) -> Entry {
        .init(value: cachedValues[id], loading: findOperations[id] != nil)
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
    public func load() async throws(API.APIError) -> Result<Void, Request.List.Failure> {
        let operation = listOperation ?? ListOperation(suite.list(), on: api) { containers in
            let tuples = containers.map { ($0.id, $0.properties) }
            let containers: [UUID: Model.Properties] = .init(uniqueKeysWithValues: tuples)
            
            // remove everything from cachedValues that is not in containers
            for (id, _) in self.cachedValues {
                if containers[id] == nil {
                    self.cachedValues.removeValue(forKey: id)
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
            }
            
            return ()
        }
        listOperation = operation
        
        defer {
            // release the operation if it hasn't been done yet
            if listOperation == operation {
                listOperation = nil
            }
        }
        
        return try await operation.get()
    }
    
    public func fetch(id: UUID) async throws(API.APIError) -> Result<Model, Request.Find.Failure> {
        let operation = findOperations[id] ?? FindOperation(suite.find(id: id), on: api) { container in
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
        
        return try await operation.get()
    }
}
