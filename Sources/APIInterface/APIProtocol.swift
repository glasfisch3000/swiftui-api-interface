public protocol APIProtocol {
    associatedtype APIError: Error
    associatedtype Request
    associatedtype Response
    
    // api contains methods/vars for retrieving fetchables
    
    func makeRequest(_ request: Request) async throws(APIError) -> Response
    func reportError(_ apiError: APIError)
}
