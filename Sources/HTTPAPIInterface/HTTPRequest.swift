import APIInterface

import Foundation
import NIOHTTP1

public protocol HTTPRequest<Response>: APIRequestProtocol where API: HTTPAPI, Failure: HTTPRequestFailure {
    var method: HTTPMethod { get }
    var path: [String] { get }
    var query: [String: QueryEncodable?] { get }
}

extension HTTPRequest {
    func makeRawRequest() -> HTTPAPI.RawRequest {
        HTTPAPI.RawRequest(method: self.method,
                           path: self.path,
                           query: self.query.compactMapValues { $0?.asQueryString })
    }
}

extension HTTPRequest where Response: Decodable {
    func decodeRawResponse(_ data: HTTPAPI.RawResponse) throws(Failure) -> Response {
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
    var method: HTTPMethod { .GET }
    var path: [String] { [Model.scheme] }
    var query: [String : QueryEncodable?] { [:] }
}


public protocol HTTPFindRequest<Model>: APIFindRequestProtocol, HTTPRequest where API: HTTPAPI, Response == ModelCodingContainer<Model>, Failure: HTTPRequestFailure { }

extension HTTPFindRequest {
    var path: [String] { [Model.scheme, id.uuidString] }
    var method: HTTPMethod { .GET }
    var query: [String : String?] { [:] }
}


public protocol HTTPCreateRequest<Model>: APICreateRequestProtocol, HTTPRequest where API: HTTPAPI, Response == ModelCodingContainer<Model>, Failure: HTTPRequestFailure { }

extension HTTPCreateRequest {
    @MainActor init(model: Model) {
        self.init(properties: model.properties)
    }
    
    var path: [String] { [Model.scheme] }
    var method: HTTPMethod { .POST }
    var query: [String : String?] { self.properties.encodeQuery().mapValues(\.asQueryString) }
}


public protocol HTTPUpdateRequest<Model>: APIUpdateRequestProtocol, HTTPRequest where API: HTTPAPI, Response == ModelCodingContainer<Model>, Failure: HTTPRequestFailure { }

extension HTTPUpdateRequest {
    @MainActor
    init(model: Model) {
        self.init(id: model.id, properties: model.properties)
    }
    
    var path: [String] { [Model.scheme, id.uuidString] }
    var method: HTTPMethod { .PATCH }
    var query: [String : String?] { properties.encodeQuery().mapValues(\.asQueryString) }
}


public protocol HTTPDeleteRequest<Model>: APIDeleteRequestProtocol, HTTPRequest where API: HTTPAPI, Response == UUID, Failure: HTTPRequestFailure { }

extension HTTPDeleteRequest {
    var path: [String] { [Model.scheme, id.uuidString] }
    var method: HTTPMethod { .DELETE }
    var query: [String : String?] { [:] }
}
