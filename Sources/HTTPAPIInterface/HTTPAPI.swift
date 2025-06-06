import APIInterface
import SwiftUI

import AsyncHTTPClient
import NIOCore
import NIOHTTP1

@MainActor
@Observable
open class HTTPAPI: APIProtocol, Sendable {
    public struct RawRequest: Sendable {
        public var method: HTTPMethod
        public var path: [String]
        public var query: [String: String]
        public var body: Data?
        
        public init(method: HTTPMethod, path: [String], query: [String : String], body: Data?) {
            self.method = method
            self.path = path
            self.query = query
            self.body = body
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
        case success(Data)
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
    open func makeRequest(_ request: RawRequest) async throws(APIError) -> RawResponse {
        func fetch(_ clientRequest: HTTPClientRequest) async throws(APIError) -> (HTTPClientResponse, Data) {
            do {
                let response = try await client.execute(clientRequest, timeout: .seconds(10))
                guard response.status.mayHaveResponseBody else {
                    throw APIError.httpStatus(response.status)
                }
                
                var buffer = try await response.body.collect(upTo: options.maxResponseSize)
                guard let data = buffer.readData(length: buffer.readableBytes) else {
                    throw APIError.emptyResponse
                }
                
                return (response, data)
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
        if let bodyData = request.body {
            clientRequest.body = .bytes(.init(data: bodyData))
        }
        
        let (response, data) = try await fetch(clientRequest)
        
        if response.status == .ok {
            return .success(data)
        }
        
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(DecodableError.self, from: data, configuration: response.status) else {
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
