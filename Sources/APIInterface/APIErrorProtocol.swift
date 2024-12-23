public protocol APIErrorProtocol: Error, Sendable {
    /// Whether or not the error should be reported to the API object on occurring.
    var shouldReport: Bool { get }
}

extension APIErrorProtocol {
    /// Whether or not the error should be reported to the API object on occurring.
    public var shouldReport: Bool { true }
}
