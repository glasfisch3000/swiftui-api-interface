import Foundation

public protocol APIRequestProtocol: Sendable {
    associatedtype API: APIProtocol
    associatedtype Response: Sendable
    associatedtype Failure: Sendable, Error
    
    /// Assembles raw request data to send to the API.
    func makeRawRequest() -> API.RawRequest
    
    /// Decodes raw response data from the API.
    func decodeRawResponse(_ data: API.RawResponse) throws(Failure) -> Response
}

extension APIRequestProtocol {
    public func run(on api: API) async throws(API.APIError) -> Result<Response, Failure> {
        let request = self.makeRawRequest()
        let response = try await api.makeRequest(request)
        return Result { () throws(Failure) -> Response in try self.decodeRawResponse(response) }
    }
}



public protocol APIListRequestProtocol<API, Model>: APIRequestProtocol where Response == [ModelCodingContainer<Model>] {
    associatedtype Model: ModelProtocol
    
    init()
}

public protocol APIFindRequestProtocol<API, Model>: APIRequestProtocol where Response == ModelCodingContainer<Model> {
    associatedtype Model: ModelProtocol
    
    var id: UUID { get }
    init(id: UUID)
}

public protocol APICreateRequestProtocol<API, Model>: APIRequestProtocol where Response == ModelCodingContainer<Model> {
    associatedtype Model: ModelProtocol
    
    var properties: Model.Properties { get }
    init(properties: Model.Properties)
}

public protocol APIUpdateRequestProtocol<API, Model>: APIRequestProtocol where Response == ModelCodingContainer<Model> {
    associatedtype Model: ModelProtocol
    
    var id: UUID { get }
    var properties: Model.Properties { get }
    init(id: UUID, properties: Model.Properties)
}

public protocol APIDeleteRequestProtocol<API, Model>: APIRequestProtocol where Response == UUID {
    associatedtype Model: ModelProtocol
    
    var id: UUID { get }
    init(id: UUID)
}
