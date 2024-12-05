public protocol APIProtocol: Sendable {
    associatedtype APIError: APIErrorProtocol
    associatedtype Request: Sendable
    associatedtype Response: Sendable
    
    // api contains methods/vars for retrieving fetchables
    
    func makeRequest(_ request: Request) async throws(APIError) -> Response
    func reportError(_ apiError: APIError) async
}

public protocol APIErrorProtocol: Error, Sendable {
    /// Whether or not the error should be reported to the API object on occurring.
    var shouldReport: Bool { get }
}

extension APIErrorProtocol {
    /// Whether or not the error should be reported to the API object on occurring.
    public var shouldReport: Bool { true }
}
