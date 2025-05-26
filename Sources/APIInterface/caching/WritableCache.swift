import Foundation
import SwiftUI

@MainActor
public protocol WritableCacheProtocol<API>: CacheProtocol {
    func execute<Request: APICreateRequest>(request: Request) async throws(API.APIError) -> Result<Request.Model, Request.Failure> where Request.API == API
    
    func execute<Request: APIUpdateRequest>(request: Request) async throws(API.APIError) -> Result<Request.Model, Request.Failure> where Request.API == API
    
	func execute<Request: APIDeleteRequest>(request: Request) async throws(API.APIError) -> Result<Request.Model.Properties, Request.Failure> where Request.API == API
}

@MainActor
@Observable
public class WritableCache<API: APIProtocol>: Cache<API>, WritableCacheProtocol {
    var updateOperations: [UUID: UpdateOperation] = [:]
    var deleteOperations: [UUID: DeleteOperation] = [:]
	var restoreOperations: [UUID: RestoreOperation] = [:]
    
    typealias CreateOperation = Operation<any ModelProtocol, Error>
    typealias UpdateOperation = Operation<any ModelProtocol, Error>
    typealias DeleteOperation = Operation<any ModelProperties, Error>
	typealias RestoreOperation = Operation<any ModelProtocol, Error>
    
    public func execute<Request: APICreateRequest>(request: Request) async throws(API.APIError) -> Result<Request.Model, Request.Failure> where API == Request.API {
        let operation = CreateOperation(request, on: api) { container in
			return request.updateCache(self, with: container)
        } handleFailure: { $0 } handleAPIError: { _ in }
        
        return try await operation.get()
            .map { $0 as! Request.Model }
            .mapError { $0 as! Request.Failure }
    }
    
    public func execute<Request: APIUpdateRequest>(request: Request) async throws(API.APIError) -> Result<Request.Model, Request.Failure> where API == Request.API {
        // wait for other operations to finish
        while let runningOperation = updateOperations[request.id] {
            _ = try? await runningOperation.get()
            
            // release the operation if it hasn't been done yet
            if updateOperations[request.id] == runningOperation {
                updateOperations[request.id] = nil
            }
        }
        
        let operation = UpdateOperation(request, on: api) { container in
			request.updateCache(self, with: container)
        } handleFailure: { $0 } handleAPIError: { _ in }
        
        updateOperations[request.id] = operation
        
        defer {
            // release the operation if it hasn't been done yet
            if updateOperations[request.id] == operation {
                updateOperations[request.id] = nil
            }
        }
        
        return try await operation.get()
            .map { $0 as! Request.Model }
            .mapError { $0 as! Request.Failure }
    }
    
	public func execute<Request: APIDeleteRequest>(request: Request) async throws(API.APIError) -> Result<Request.Model.Properties, Request.Failure> where API == Request.API {
		if let restoreOperation = restoreOperations[request.id] {
			_ = try? await restoreOperation.get()
		}
		
        let runningOperation = deleteOperations[request.id]
        let operation = runningOperation ?? DeleteOperation(request, on: api) { container in
			request.updateCache(self, with: container)
        } handleFailure: { $0 } handleAPIError: { _ in }
        
        deleteOperations[request.id] = operation
        
        defer {
            // release the operation if it hasn't been done yet
            if deleteOperations[request.id] == operation {
                deleteOperations.removeValue(forKey: request.id)
            }
        }
        
        return try await operation.get()
			.map { $0 as! Request.Model.Properties }
            .mapError { $0 as! Request.Failure }
    }
	
	public func execute<Request: APIRestoreRequest>(request: Request) async throws(API.APIError) -> Result<Request.Model, Request.Failure> where API == Request.API {
		if let deleteOperation = deleteOperations[request.id] {
			_ = try? await deleteOperation.get()
		}
		
		let runningOperation = restoreOperations[request.id]
		let operation = runningOperation ?? RestoreOperation(request, on: api) { container in
			request.updateCache(self, with: container)
		} handleFailure: { $0 } handleAPIError: { _ in }
		
		restoreOperations[request.id] = operation
		
		defer {
			// release the operation if it hasn't been done yet
			if restoreOperations[request.id] == operation {
				restoreOperations.removeValue(forKey: request.id)
			}
		}
		
		return try await operation.get()
			.map { $0 as! Request.Model }
			.mapError { $0 as! Request.Failure }
	}
}
