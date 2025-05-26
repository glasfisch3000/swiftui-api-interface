import Foundation

public protocol APIRequest: Sendable {
    associatedtype API: APIProtocol
    associatedtype Response: Sendable
    associatedtype Failure: Sendable, Error
    
    /// Assembles raw request data to send to the API.
    func makeRawRequest() -> API.RawRequest
    
    /// Decodes raw response data from the API.
    func decodeRawResponse(_ data: API.RawResponse) throws(Failure) -> Response
}

extension APIRequest {
    public func run(on api: API) async throws(API.APIError) -> Result<Response, Failure> {
        let request = self.makeRawRequest()
        let response = try await api.makeRequest(request)
        return Result { () throws(Failure) -> Response in try self.decodeRawResponse(response) }
    }
}



public protocol APIListRequest<API, Model>: APIRequest where Response == [ModelCodingContainer<Model>] {
    associatedtype Model: ModelProtocol where Model.API == API
    associatedtype FilterOptions: Sendable, Hashable
    
    /// A list request's filter options are query parameters that apply a specific selection to the fetched models, such as "all models that have the property x". This does not include things like sorting options or unspecific limitations like "the first 100 models".
    var filterOptions: FilterOptions { get }
    
    @MainActor
    func filterModel(_ model: Model) -> Bool
	
	/// Called by a cache instance after the request has completed. Updates the cache's stored models with the new data from the API response.
	@MainActor
	func updateCache(_ cache: any CacheProtocol<API>, with response: Response) -> [Model]
}

public protocol APIFindRequest<API, Model>: APIRequest where Response == ModelCodingContainer<Model> {
    associatedtype Model: ModelProtocol where Model.API == API
    
    var id: UUID { get }
	
	/// Called by a cache instance after the request has completed. Updates the cache's stored models with the new data from the API response.
	@MainActor
	func updateCache(_ cache: any CacheProtocol<API>, with response: Response) -> Model
}

public protocol APICreateRequest<API, Model>: APIRequest where Response == ModelCodingContainer<Model> {
    associatedtype Model: ModelProtocol where Model.API == API
    
    var properties: Model.Properties { get }
	
	/// Called by a cache instance after the request has completed. Updates the cache's stored models with the new data from the API response.
	@MainActor
	func updateCache(_ cache: any CacheProtocol<API>, with response: Response) -> Model
}

public protocol APIUpdateRequest<API, Model>: APIRequest where Response == ModelCodingContainer<Model> {
    associatedtype Model: ModelProtocol where Model.API == API
    
    var id: UUID { get }
    var properties: Model.Properties { get }
	
	/// Called by a cache instance after the request has completed. Updates the cache's stored models with the new data from the API response.
	@MainActor
	func updateCache(_ cache: any CacheProtocol<API>, with response: Response) -> Model
}

public protocol APIDeleteRequest<API, Model>: APIRequest where Response == ModelCodingContainer<Model> {
    associatedtype Model: ModelProtocol where Model.API == API
    
    var id: UUID { get }
	
	/// Called by a cache instance after the request has completed. Updates the cache's stored models with the new data from the API response.
	@MainActor
	func updateCache(_ cache: any CacheProtocol<API>, with response: Response) -> Model.Properties
}

public protocol APIRestoreRequest<API, Model>: APIRequest where Response == ModelCodingContainer<Model> {
	associatedtype Model: SoftDeletableModelProtocol where Model.API == API
	
	var id: UUID { get }
	
	/// Called by a cache instance after the request has completed. Updates the cache's stored models with the new data from the API response.
	@MainActor
	func updateCache(_ cache: any CacheProtocol<API>, with response: Response) -> Model
}
