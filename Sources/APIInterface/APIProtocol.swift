public protocol APIProtocol: Sendable {
    associatedtype APIError: APIErrorProtocol
    associatedtype RawRequest: Sendable
    associatedtype RawResponse: Sendable
    
    // api contains methods/vars for retrieving fetchables
    
    func makeRequest(_ request: RawRequest) async throws(APIError) -> RawResponse
    func reportError(_ apiError: APIError) async
}
