import Foundation
import SwiftUI

@MainActor
@Observable
public class Cache<API: APIProtocol, Model: ModelProtocol, ListRequest: APIListRequestProtocol<API, Model>, FindRequest: APIFindRequestProtocol<API, Model>> {
    public struct Entry {
        public var value: Model?
        public var loading: Bool
        
        public init(value: Model? = nil, loading: Bool = false) {
            self.value = value
            self.loading = loading
        }
    }
    
    public var api: API
    
    var cachedValues: [UUID: Model]
    var listFailure: ListRequest.Failure?
    
    var listOperation: APIOperation<ListRequest>? = nil
    var findOperations: [UUID: APIOperation<FindRequest>] = [:]
    
    public init(api: API, listRequest: ListRequest.Type = ListRequest.self, findRequest: FindRequest.Type = FindRequest.self) {
        self.api = api
        self.cachedValues = [:]
    }
}

struct APIOperation<Request: APIRequestProtocol>: Sendable {
    var request: Request
    var task: Task<Result<Result<Request.Response, Request.Failure>, Request.API.APIError>, Never>
    
    init(_ request: Request, on api: Request.API) {
        self.request = request
        self.task = Task {
            do throws(Request.API.APIError) {
                return .success(try await request.run(on: api))
            } catch {
                return .failure(error)
            }
        }
    }
}

extension Cache {
    public var isLoading: Bool { listOperation != nil }
    
    public var models: Result<[Model], ListRequest.Failure> {
        if let listFailure = listFailure {
            return .failure(listFailure)
        }
        
        return .success(cachedValues.values.map(\.self))
    }
    
    public subscript(id: UUID) -> Entry {
        .init(value: cachedValues[id], loading: listOperation != nil || findOperations[id] != nil)
    }
    
    public func load() async {
        guard listOperation == nil else { return }
        
        let operation = APIOperation(ListRequest(), on: api)
        listOperation = operation
        defer { listOperation = nil }
        
        switch await operation.task.value {
        case .success(.success(let containers)):
            let containers = [UUID: Model.Properties]
                .init(containers.map { ($0.id, $0.properties) }) { first, _ in first }
            
            for (id, _) in cachedValues {
                if containers[id] != nil {
                    cachedValues.removeValue(forKey: id)
                }
            }
            
            for (id, properties) in containers {
                if let model = cachedValues[id] {
                    model.properties = properties
                } else {
                    cachedValues[id] = Model(id: id, properties: properties)
                }
            }
            
        case .success(.failure(let failure)):
            self.listFailure = failure
            
        case .failure(_):
            break
        }
    }
}
