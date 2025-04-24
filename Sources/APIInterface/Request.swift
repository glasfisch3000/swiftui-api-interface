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
    associatedtype Model: ModelProtocol
    
    init(parent: Parent)
}

public protocol APIFindRequest<API, Model>: APINestedRequest where Response == ModelCodingContainer<Model> {
    associatedtype Model: ModelProtocol
    
    var id: UUID { get }
    init(id: UUID, parent: Parent)
}

public protocol APICreateRequest<API, Model>: APINestedRequest where Response == ModelCodingContainer<Model> {
    associatedtype Model: ModelProtocol
    
    var properties: Model.Properties { get }
    init(properties: Model.Properties, parent: Parent)
}

public protocol APIUpdateRequest<API, Model>: APINestedRequest where Response == ModelCodingContainer<Model> {
    associatedtype Model: ModelProtocol
    
    var id: UUID { get }
    var properties: Model.Properties { get }
    init(id: UUID, properties: Model.Properties, parent: Parent)
}

public protocol APIDeleteRequest<API, Model>: APINestedRequest where Response == UUID {
    associatedtype Model: ModelProtocol
    
    var id: UUID { get }
    init(id: UUID, parent: Parent)
}
