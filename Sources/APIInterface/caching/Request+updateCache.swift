import Foundation

extension APIListRequest {
	@MainActor
	public func updateCache(_ cache: any CacheProtocol<API>, with containers: Response) -> [Model] {
		cache.listFailures.removeValue(forKey: self.cacheSignature)
		
		let tuples = containers.map { ($0.id, $0.properties) }
		
		// remove everything from cachedValues that was apparently deleted
		cache.cachedModels
			.compactMapValues { $0 as? Model }
			.filter { (key, value) in self.filterModel(value) && !tuples.contains { $0.0 == key } }
			.forEach { cache.removeModel(id: $0.key) }
		
		return tuples.map(cache.setModel)
	}
}

extension APIFindRequest {
	@MainActor
	public func updateCache(_ cache: any CacheProtocol<API>, with container: Response) -> Model {
		return cache.setModel(id: container.id, properties: container.properties)
	}
}

extension APICreateRequest {
	@MainActor
	public func updateCache(_ cache: any CacheProtocol<API>, with container: Response) -> Model {
		return cache.setModel(id: container.id, properties: container.properties)
	}
}

extension APIUpdateRequest {
	@MainActor
	public func updateCache(_ cache: any CacheProtocol<API>, with container: Response) -> Model {
		return cache.setModel(id: container.id, properties: container.properties)
	}
}

extension APIDeleteRequest {
	@MainActor
	public func updateCache(_ cache: any CacheProtocol<API>, with container: Response) -> Model.Properties {
		cache.removeModel(id: container.id)
		return container.properties
	}
}

extension APIDeleteRequest where Model: SoftDeletableModelProtocol {
	@MainActor
	public func updateCache(_ cache: any CacheProtocol<API>, with container: Response) -> Model.Properties {
		(cache.setModel(id: container.id, properties: container.properties) as Model).properties
	}
}

extension APIRestoreRequest {
	@MainActor
	public func updateCache(_ cache: any CacheProtocol<API>, with container: Response) -> Model {
		cache.setModel(id: container.id, properties: container.properties) as Model
	}
}
