import APIInterface

import Foundation
import NIOHTTP1

public protocol HTTPRequest<Response>: APIRequest where API: HTTPAPI {
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

extension HTTPRequest where Response: Decodable, Failure: HTTPRequestFailure {
    public func decodeRawResponse(_ data: HTTPAPI.RawResponse) throws(Failure) -> Response {
        switch data {
        case .disallowed: throw .disallowed
        case .notFound: throw .notFound
        case .success(let node):
            do {
                return try Response(from: node)
            } catch {
                throw .decodingError(error)
            }
        }
    }
}



public protocol HTTPRequestFailure: Error {
    static var notFound: Self { get }
    static var disallowed: Self { get }
    static func decodingError(_ error: Error) -> Self
}



public protocol HTTPRequestSuite<API, Model>: APIRequestSuite, HTTPRequest
where API: HTTPAPI, List: HTTPListRequest, Find: HTTPFindRequest { }

public protocol HTTPWritableRequestSuite<API, Model>: HTTPRequestSuite, APIWritableRequestSuite
where Create: HTTPCreateRequest, Update: HTTPUpdateRequest, Delete: HTTPDeleteRequest { }



public protocol HTTPListRequest<Model, Parent>: APIListRequest, HTTPRequest
where Failure: HTTPRequestFailure, Parent: HTTPRequest { }

extension HTTPListRequest {
    public var method: HTTPMethod { .GET }
    public var path: [String] { parent.path + [Model.scheme] }
    public var query: [String : QueryEncodable?] { [:] }
}



public protocol HTTPFindRequest<Model, Parent>: APIFindRequest, HTTPRequest
where Failure: HTTPRequestFailure, Parent: HTTPRequest { }

extension HTTPFindRequest {
    public var path: [String] { parent.path + [Model.scheme, id.uuidString] }
    public var method: HTTPMethod { .GET }
    public var query: [String : QueryEncodable?] { [:] }
}



public protocol HTTPCreateRequest<Model, Parent>: APICreateRequest, HTTPRequest
where Failure: HTTPRequestFailure, Parent: HTTPRequest { }

extension HTTPCreateRequest {
    @MainActor
    public init(model: Model, parent: Parent) {
        self.init(properties: model.properties, parent: parent)
    }
    
    public var path: [String] { parent.path + [Model.scheme] }
    public var method: HTTPMethod { .POST }
    public var query: [String : QueryEncodable?] { self.properties.encodeQuery() }
}



public protocol HTTPUpdateRequest<Model>: APIUpdateRequest, HTTPRequest
where Failure: HTTPRequestFailure, Parent: HTTPRequest { }

extension HTTPUpdateRequest {
    @MainActor
    public init(model: Model, parent: Parent) {
        self.init(id: model.id, properties: model.properties, parent: parent)
    }
    
    public var path: [String] { parent.path + [Model.scheme, id.uuidString] }
    public var method: HTTPMethod { .PATCH }
    public var query: [String : QueryEncodable?] { properties.encodeQuery() }
}



public protocol HTTPDeleteRequest<Model>: APIDeleteRequest, HTTPRequest
where Failure: HTTPRequestFailure, Parent: HTTPRequest { }

extension HTTPDeleteRequest {
    public var path: [String] { parent.path + [Model.scheme, id.uuidString] }
    public var method: HTTPMethod { .DELETE }
    public var query: [String : QueryEncodable?] { [:] }
}
