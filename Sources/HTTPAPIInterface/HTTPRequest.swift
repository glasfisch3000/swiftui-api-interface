import APIInterface

import Foundation
import NIOHTTP1

public protocol HTTPRequest<Response>: APIRequest where API: HTTPAPI {
    var method: HTTPMethod { get }
    var path: [String] { get }
    var query: [String: QueryEncodable?] { get }
    var body: Data? { get }
}

extension HTTPRequest {
    public func makeRawRequest() -> HTTPAPI.RawRequest {
        HTTPAPI.RawRequest(method: self.method,
                           path: self.path,
                           query: self.query.compactMapValues { $0?.asQueryString },
                           body: self.body)
    }
}

extension HTTPRequest where Response: Decodable, Failure: HTTPRequestFailure {
    public func decodeRawResponse(_ data: HTTPAPI.RawResponse) throws(Failure) -> Response {
        switch data {
        case .disallowed: throw .disallowed
        case .notFound: throw .notFound
        case .success(let data):
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(Response.self, from: data)
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



public protocol HTTPListRequest<Model>: APIListRequest, HTTPRequest where Failure: HTTPRequestFailure { }

extension HTTPListRequest {
    public var method: HTTPMethod { .GET }
    public var path: [String] { [Model.scheme] }
    public var query: [String : QueryEncodable?] { [:] }
    public var body: Data? { nil }
}



public protocol HTTPFindRequest<Model>: APIFindRequest, HTTPRequest where Failure: HTTPRequestFailure { }

extension HTTPFindRequest {
    public var path: [String] { [Model.scheme, id.uuidString] }
    public var method: HTTPMethod { .GET }
    public var query: [String : QueryEncodable?] { [:] }
    public var body: Data? { nil }
}



public protocol HTTPCreateRequest<Model>: APICreateRequest, HTTPRequest where Failure: HTTPRequestFailure { }

extension HTTPCreateRequest {
    public var path: [String] { [Model.scheme] }
    public var method: HTTPMethod { .POST }
    public var query: [String : QueryEncodable?] { [:] }
    public var body: Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self.properties)
    }
}



public protocol HTTPUpdateRequest<Model>: APIUpdateRequest, HTTPRequest where Failure: HTTPRequestFailure { }

extension HTTPUpdateRequest {
    public var path: [String] { [Model.scheme, id.uuidString] }
    public var method: HTTPMethod { .PATCH }
    public var query: [String : QueryEncodable?] { properties.encodeQuery() }
    public var body: Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self.properties)
    }
}



public protocol HTTPDeleteRequest<Model>: APIDeleteRequest, HTTPRequest where Failure: HTTPRequestFailure { }

extension HTTPDeleteRequest {
    public var path: [String] { [Model.scheme, id.uuidString] }
    public var method: HTTPMethod { .DELETE }
    public var query: [String : QueryEncodable?] { [:] }
    public var body: Data? { nil }
}



public protocol HTTPSoftDeleteRequest<Model>: APISoftDeleteRequest, HTTPRequest where Failure: HTTPRequestFailure { }

extension HTTPSoftDeleteRequest {
	public var path: [String] { [Model.scheme, id.uuidString] }
	public var method: HTTPMethod { .DELETE }
	public var query: [String : QueryEncodable?] { ["force" : self.force] }
	public var body: Data? { nil }
}



public protocol HTTPRestoreRequest<Model>: APIRestoreRequest, HTTPRequest where Failure: HTTPRequestFailure { }

extension HTTPRestoreRequest {
	public var path: [String] { [Model.scheme, id.uuidString] }
	public var method: HTTPMethod { .PUT }
	public var query: [String : QueryEncodable?] { [:] }
	public var body: Data? { nil }
}
