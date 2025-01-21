public protocol APIProtocol: Sendable {
    associatedtype APIError: Error, Sendable
    associatedtype RawRequest: Sendable
    associatedtype RawResponse: Sendable
    
    // api contains methods/vars for retrieving fetchables
    
    func makeRequest(_ request: RawRequest) async throws(APIError) -> RawResponse
}
