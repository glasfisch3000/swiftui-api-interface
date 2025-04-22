import APIInterface

import NIOHTTP1

public protocol HTTPRequest<Response>: APIRequestProtocol where API == HTTPAPI, Failure: HTTPRequestFailure {
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
