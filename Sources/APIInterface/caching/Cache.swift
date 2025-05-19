import Foundation
import SwiftUI

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
			request.updateCache(self, with: codingContainers)
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
			request.updateCache(self, with: codingContainer)
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
