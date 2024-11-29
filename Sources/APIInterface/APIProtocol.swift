public protocol APIProtocol: Sendable {
    associatedtype APIError: APIErrorProtocol
    associatedtype Request: Sendable
    associatedtype Response: Sendable
    
    // api contains methods/vars for retrieving fetchables
    
    func makeRequest(_ request: Request) async throws(APIError) -> Response
    mutating func reportError(_ apiError: APIError) async
}

public protocol APIErrorProtocol: Error, Sendable {
    var shouldReport: Bool { get }
}

extension APIErrorProtocol {
    public var shouldReport: Bool { true }
}
