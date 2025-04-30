import APIInterface
import SwiftUI

import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import JSON
import JSONLegacy

@MainActor
@Observable
public final class HTTPAPI: APIProtocol, Sendable {
    public struct RawRequest: Sendable {
        public var method: HTTPMethod
        public var path: [String]
        public var query: [String: String]
        
        public init(method: HTTPMethod, path: [String], query: [String : String]) {
            self.method = method
            self.path = path
            self.query = query
        }
    }
    
    public typealias RawResponse = JSON.Node
    
    public enum APIError: Sendable, Error, Hashable {
        case emptyResponse
        case invalidRequest
        case invalidAuthentication
        case disallowed
        case clientShutdown
        case httpStatus(HTTPResponseStatus)
        case other
        
        public enum DecodableError: Decodable {
            case invalidQuery
            case missingAuthentication
            case invalidAuthentication
            case disallowed
            
            public var asAPIError: APIError {
                switch self {
                case .invalidQuery: .invalidRequest
                case .missingAuthentication, .invalidAuthentication: .invalidAuthentication
                case .disallowed: .disallowed
                }
            }
        }
    }
    
    public let client: HTTPClient
    public var endpoint: HTTPEndpoint
    public var credentials: Credentials?
    
    public var options: Options = .default
    
    public init(client: HTTPClient = .shared, endpoint: HTTPEndpoint, credentials: Credentials? = nil) {
        self.client = client
        self.endpoint = endpoint
        self.credentials = credentials
    }
    
    /// Sends a raw API request and checks for errors, but doesn't decode a response.
    public func makeRequest(_ request: RawRequest) async throws(APIError) -> RawResponse {
        let url = endpoint.makeURL(for: request)
        let auth = credentials?.makeHTTPBasicAuthorization()
        
        do {
            var clientRequest = HTTPClientRequest(url: url)
            clientRequest.method = request.method
            if let auth = auth {
                clientRequest.headers.add(name: "Authorization", value: auth)
            }
            
            let response = try await client.execute(clientRequest, timeout: .seconds(10))
            
            guard response.status == HTTPResponseStatus.ok else {
                throw APIError.httpStatus(response.status)
            }
            
            var buffer = try await response.body.collect(upTo: options.maxResponseSize)
            guard let jsonString = buffer.readString(length: buffer.readableBytes, encoding: .utf8) else {
                throw APIError.emptyResponse
            }
            
            enum CodingKey: String {
                case error
                case success
            }
            
            let json = try JSON.Node(parsing: jsonString)
            let object = try JSON.ObjectDecoder<CodingKey>(json: json)
            
            if let node = object[.error]?.value {
                throw (try? APIError.DecodableError(from: node).asAPIError) ?? .emptyResponse
            }
            
            if let value = object[.success]?.value {
                return value
            }
            
            throw APIError.emptyResponse
        } catch let error as HTTPClientError {
            print(error)
            switch error {
            case .invalidURL, .emptyScheme, .emptyHost: throw APIError.invalidRequest
            case .alreadyShutdown: throw APIError.clientShutdown
            default: throw APIError.other
            }
        } catch let error as APIError {
            print(error)
            throw error
        } catch let error {
            print(error)
            throw APIError.other
        }
    }
}

extension HTTPAPI {
    public struct Options: Sendable, Hashable {
        public static let `default` = Self()
        
        public var maxResponseSize: Int = 10_000_000
        
        init() { }
    }
}
