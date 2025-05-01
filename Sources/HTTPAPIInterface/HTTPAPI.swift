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
    
    public enum APIError: Error, Hashable {
        case emptyResponse
        case invalidRequest
        case invalidAuthentication
        case clientShutdown
        case httpStatus(HTTPResponseStatus)
        case serverError
        case other
    }
    
    public enum RawResponse: Sendable {
        case success(JSON.Node)
        case disallowed
        case notFound
    }
    
    struct DecodableError: DecodableWithConfiguration {
        enum ErrorCode: String, Decodable {
            case missingAuthentication
            case invalidAuthentication
            case disallowed
            case invalidQuery
            case invalidRequestBody
            case notFound
            case internalError
            
            var expectedStatusCode: HTTPResponseStatus {
                switch self {
                case .missingAuthentication: .unauthorized
                case .invalidAuthentication: .unauthorized
                case .disallowed: .forbidden
                case .invalidQuery: .badRequest
                case .invalidRequestBody: .badRequest
                case .notFound: .notFound
                case .internalError: .internalServerError
                }
            }
        }
        
        enum DecodingError: Error {
            case unknownCode
            case statusMismatch
            case other
        }
        
        enum CodingKeys: CodingKey {
            case error
            case description
        }
        
        typealias DecodingConfiguration = HTTPResponseStatus
        
        var error: ErrorCode
        var description: String?
        
        init(from decoder: any Decoder, configuration: HTTPResponseStatus) throws(DecodingError) {
            guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
                throw .other
            }
            
            guard let error = try? container.decode(ErrorCode.self, forKey: .error) else {
                throw .unknownCode
            }
            
            guard error.expectedStatusCode == configuration else {
                throw .statusMismatch
            }
            
            self.error = error
            self.description = try? container.decodeIfPresent(String.self, forKey: .description)
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
        func fetch(_ clientRequest: HTTPClientRequest) async throws(APIError) -> (HTTPClientResponse, JSON.Node) {
            do {
                let response = try await client.execute(clientRequest, timeout: .seconds(10))
                guard response.status.mayHaveResponseBody else {
                    throw APIError.httpStatus(response.status)
                }
                
                var buffer = try await response.body.collect(upTo: options.maxResponseSize)
                guard let jsonString = buffer.readString(length: buffer.readableBytes, encoding: .utf8) else {
                    throw APIError.emptyResponse
                }
                
                let json = try JSON.Node(parsing: jsonString)
                return (response, json)
            } catch let error as HTTPClientError {
                print(error)
                switch error {
                case .invalidURL, .emptyScheme, .emptyHost: throw APIError.invalidRequest
                case .alreadyShutdown: throw APIError.clientShutdown
                default: throw .other
                }
            } catch let error as APIError {
                print(error)
                throw error
            } catch let error {
                print(error)
                throw APIError.other
            }
        }
        
        let url = endpoint.makeURL(for: request)
        let auth = credentials?.makeHTTPBasicAuthorization()
        
        var clientRequest = HTTPClientRequest(url: url)
        clientRequest.method = request.method
        if let auth = auth {
            clientRequest.headers.add(name: "Authorization", value: auth)
        }
        
        let (response, json) = try await fetch(clientRequest)
        
        if response.status == .ok {
            return .success(json)
        }
        
        guard let decoded = try? DecodableError(from: json, configuration: response.status) else {
            throw APIError.httpStatus(response.status)
        }
        
        switch decoded.error {
        case .missingAuthentication: throw APIError.invalidAuthentication
        case .invalidAuthentication: throw APIError.invalidAuthentication
        case .disallowed: return .disallowed
        case .invalidQuery: throw APIError.invalidRequest
        case .invalidRequestBody: throw APIError.invalidRequest
        case .notFound: return .notFound
        case .internalError: throw APIError.serverError
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
