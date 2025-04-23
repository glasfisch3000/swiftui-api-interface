import APIInterface

import Foundation
import NIOHTTP1

public protocol HTTPRequest<Response>: APIRequestProtocol where API: HTTPAPI, Failure: HTTPRequestFailure {
    var method: HTTPMethod { get }
    var path: [String] { get }
    var query: [String: QueryEncodable?] { get }
}

extension HTTPRequest {
    public func makeRawRequest() -> HTTPAPI.RawRequest {
        HTTPAPI.RawRequest(method: self.method,
                           path: self.path,
                           query: self.query.compactMapValues { $0?.asQueryString })
    }
}

extension HTTPRequest where Response: Decodable {
    public func decodeRawResponse(_ data: HTTPAPI.RawResponse) throws(Failure) -> Response {
        do {
            return try Response(from: data)
        } catch {
            throw .init(decodingError: error)
        }
    }
}



public protocol HTTPRequestFailure: Error {
    init(decodingError: Error)
}



public protocol HTTPRequestSuite<API, Model>: APIRequestSuite where API: HTTPAPI, List: HTTPListRequest, Find: HTTPFindRequest { }
public protocol HTTPWritableRequestSuite<API, Model>: HTTPRequestSuite, APIWritableRequestSuite where Create: HTTPCreateRequest, Update: HTTPUpdateRequest, Delete: HTTPDeleteRequest { }


public protocol HTTPListRequest<Model>: APIListRequestProtocol, HTTPRequest where API: HTTPAPI, Response == [ModelCodingContainer<Model>], Failure: HTTPRequestFailure { }

extension HTTPListRequest {
    public var method: HTTPMethod { .GET }
    public var path: [String] { [Model.scheme] }
    public var query: [String : QueryEncodable?] { [:] }
}


public protocol HTTPFindRequest<Model>: APIFindRequestProtocol, HTTPRequest where API: HTTPAPI, Response == ModelCodingContainer<Model>, Failure: HTTPRequestFailure { }

extension HTTPFindRequest {
    public var path: [String] { [Model.scheme, id.uuidString] }
    public var method: HTTPMethod { .GET }
    public var query: [String : QueryEncodable?] { [:] }
}


public protocol HTTPCreateRequest<Model>: APICreateRequestProtocol, HTTPRequest where API: HTTPAPI, Response == ModelCodingContainer<Model>, Failure: HTTPRequestFailure { }

extension HTTPCreateRequest {
    @MainActor
    public init(model: Model) {
        self.init(properties: model.properties)
    }
    
    public var path: [String] { [Model.scheme] }
    public var method: HTTPMethod { .POST }
    public var query: [String : QueryEncodable?] { self.properties.encodeQuery() }
}


public protocol HTTPUpdateRequest<Model>: APIUpdateRequestProtocol, HTTPRequest where API: HTTPAPI, Response == ModelCodingContainer<Model>, Failure: HTTPRequestFailure { }

extension HTTPUpdateRequest {
    @MainActor
    public init(model: Model) {
        self.init(id: model.id, properties: model.properties)
    }
    
    public var path: [String] { [Model.scheme, id.uuidString] }
    public var method: HTTPMethod { .PATCH }
    public var query: [String : QueryEncodable?] { properties.encodeQuery() }
}


public protocol HTTPDeleteRequest<Model>: APIDeleteRequestProtocol, HTTPRequest where API: HTTPAPI, Response == UUID, Failure: HTTPRequestFailure { }

extension HTTPDeleteRequest {
    public var path: [String] { [Model.scheme, id.uuidString] }
    public var method: HTTPMethod { .DELETE }
    public var query: [String : QueryEncodable?] { [:] }
}
