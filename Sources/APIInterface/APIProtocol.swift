public protocol APIProtocol: Sendable {
    associatedtype APIError: Error, Sendable
    associatedtype Request: Sendable
    associatedtype Response: Sendable
    
    // api contains methods/vars for retrieving fetchables
    
    func makeRequest(_ request: Request) async throws(APIError) -> Response
    func reportError(_ apiError: APIError) async
}
