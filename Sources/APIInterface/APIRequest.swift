public protocol APIRequest: Sendable {
    associatedtype API: APIProtocol
    associatedtype Response: Sendable
    
    /// Assembles raw request data to send to the API.
    func makeRawRequest() -> API.RawRequest
    
    /// Decodes raw response data from the API.
    func decodeRawResponse(_ data: API.RawResponse) -> Response
}

public protocol ThrowingAPIRequest: APIRequest where Response == Result<Value, Failure> {
    associatedtype Value: Sendable
    associatedtype Failure: Sendable, Error
    
    /// Decodes raw response data from the API, throwing an error of type `Failure` if the data is invalid.
    func decodeThrowingRawResponse(_ data: API.RawResponse) throws(Failure) -> Value
}

extension ThrowingAPIRequest {
    public func decodeRawResponse(_ data: API.RawResponse) -> Response {
        do throws(Failure) {
            return .success(try decodeThrowingRawResponse(data))
        } catch {
            return .failure(error)
        }
    }
}

extension APIRequest {
    public func run(on api: API) async throws(API.APIError) -> Response {
        let request = self.makeRawRequest()
        let response = try await api.makeRequest(request)
        return self.decodeRawResponse(response)
    }
}
