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
