public protocol APIProtocol: Sendable {
    associatedtype APIError: APIErrorProtocol
    associatedtype Request: Sendable
    associatedtype Response: Sendable
    
    // api contains methods/vars for retrieving fetchables
    
    func makeRequest(_ request: Request) async throws(APIError) -> Response
    func reportError(_ apiError: APIError) async
}

extension APIProtocol {
    public func makeRequest<Value: Sendable>(
        _ request: Request,
        as type: Value.Type = Value.self,
        using transform: @Sendable @escaping (Response) throws(APIError) -> Value
    ) async throws(APIError) -> Value {
        let response = try await self.makeRequest(request)
        return try transform(response)
    }
}
