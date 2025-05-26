import Foundation
import SwiftUI

@MainActor
public protocol CacheProtocol<API>: Sendable {
    associatedtype API: APIProtocol
    
    var api: API { get }
    
    var cachedModels: [UUID: any ModelProtocol] { get nonmutating set }
	var findRequestCache: [UUID: RequestCacheResult] { get nonmutating set }
	var listRequestCache: [CacheListRequestSignature: RequestCacheResult] { get nonmutating set }
    
    func get<Request: APIListRequest>(_ request: Request) -> CacheEntry<[UUID: Request.Model], Request.Failure>? where Request.API == API
    func get<Request: APIFindRequest>(_ request: Request) -> CacheEntry<Request.Model?, Request.Failure>? where Request.API == API
    
    @discardableResult
    func execute<Request: APIListRequest>(request: Request) async throws(API.APIError) -> Result<[Request.Model], Request.Failure> where Request.API == API
    
    @discardableResult
    func execute<Request: APIFindRequest>(request: Request) async throws(API.APIError) -> Result<Request.Model, Request.Failure> where Request.API == API
	
	/// Clears all cached data.
	func nuke(keepingCapacity: Bool)
}

extension CacheProtocol {
	public func removeModel(id: UUID) {
		self.cachedModels.removeValue(forKey: id)
		self.findRequestCache.removeValue(forKey: id)
	}
	
	@discardableResult
	public func setModel<Model: ModelProtocol>(id: UUID, properties: Model.Properties) -> Model where Model.API == Self.API {
		self.findRequestCache.removeValue(forKey: id)
		if let model = cachedModels[id] as? Model {
			model.properties = properties
			model.lastUpdated = .now
			return model
		} else {
			let model = Model(id: id, properties: properties, cache: self)
			cachedModels[id] = model
			return model
		}
	}
}

extension CacheProtocol {
	public func nuke(keepingCapacity: Bool = false) {
		self.cachedModels.removeAll(keepingCapacity: keepingCapacity)
		self.findRequestCache.removeAll(keepingCapacity: keepingCapacity)
		self.listRequestCache.removeAll(keepingCapacity: keepingCapacity)
	}
}

public struct RequestCacheResult: Sendable {
	var error: Error?
}
