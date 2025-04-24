import Foundation
import SwiftUI

@MainActor
@Observable
public class WritableCache<API: APIProtocol, Model: ModelProtocol, Request: APIWritableRequestSuite<API, Model>>: Cache<API, Model, Request> {
    var updateOperations: [UUID: UpdateOperation] = [:]
    var deleteOperations: [UUID: DeleteOperation] = [:]
    
    typealias CreateOperation = Operation<Model, Request.Create>
    typealias UpdateOperation = Operation<Model, Request.Update>
    typealias DeleteOperation = Operation<UUID, Request.Delete>
    
    public func create(properties: Model.Properties) async throws(API.APIError) -> Result<Model, Request.Create.Failure> {
        let operation = CreateOperation(suite.create(properties: properties), on: api) { container in
            let model = Model(id: container.id, properties: container.properties)
            self.cachedValues[container.id] = model
            return model
        }
        return try await operation.get()
    }
    
    public func update(id: UUID, properties: Model.Properties) async throws(API.APIError) -> Result<Model, Request.Update.Failure> {
        // wait for other operations to finish
        while let runningOperation = updateOperations[id] {
            _ = try? await runningOperation.get()
            
            // release the operation if it hasn't been done yet
            if updateOperations[id] == runningOperation {
                updateOperations[id] = nil
            }
        }
        
        let operation = UpdateOperation(suite.update(id: id, properties: properties), on: api) { container in
            if let model = self.cachedValues[container.id] {
                model.properties = container.properties
                model.lastUpdated = .now
                return model
            } else {
                let model = Model(id: container.id, properties: container.properties)
                self.cachedValues[container.id] = model
                return model
            }
        }
        updateOperations[id] = operation
        
        defer {
            // release the operation if it hasn't been done yet
            if updateOperations[id] == operation {
                updateOperations[id] = nil
            }
        }
        
        return try await operation.get()
    }
    
    public func delete(id: UUID) async throws(API.APIError) -> Result<UUID, Request.Delete.Failure> {
        let operation = deleteOperations[id] ?? DeleteOperation(suite.delete(id: id), on: api) { id in
            self.cachedValues.removeValue(forKey: id)
            return id
        }
        deleteOperations[id] = operation
        
        defer {
            // release the operation if it hasn't been done yet
            if deleteOperations[id] == operation {
                deleteOperations.removeValue(forKey: id)
            }
        }
        
        return try await operation.get()
    }
}
