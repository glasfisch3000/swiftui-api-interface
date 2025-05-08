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



public protocol APINestedRequest<API, Parent>: APIRequest {
    associatedtype Parent: APIRequest
    
    var parent: Parent { get }
}



public protocol APIListRequest<API, Model>: APINestedRequest where Response == [ModelCodingContainer<Model>] {
    associatedtype Model: ModelProtocol where Model.API == API
    associatedtype FilterOptions: Sendable, Hashable
    
    /// A list request's filter options are query parameters that apply a specific selection to the fetched models, such as "all models that have the property x". This does not include things like sorting options or unspecific limitations like "the first 100 models".
    var filterOptions: FilterOptions { get }
    
    @MainActor
    func filterModel(_ model: Model) -> Bool
}

public protocol APIFindRequest<API, Model>: APINestedRequest where Response == ModelCodingContainer<Model> {
    associatedtype Model: ModelProtocol where Model.API == API
    
    var id: UUID { get }
}

public protocol APICreateRequest<API, Model>: APINestedRequest where Response == ModelCodingContainer<Model> {
    associatedtype Model: ModelProtocol where Model.API == API
    
    var properties: Model.Properties { get }
}

public protocol APIUpdateRequest<API, Model>: APINestedRequest where Response == ModelCodingContainer<Model> {
    associatedtype Model: ModelProtocol where Model.API == API
    
    var id: UUID { get }
    var properties: Model.Properties { get }
}

public protocol APIDeleteRequest<API, Model>: APINestedRequest where Response == UUID {
    associatedtype Model: ModelProtocol where Model.API == API
    
    var id: UUID { get }
}
