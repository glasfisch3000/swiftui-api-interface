import Foundation

public protocol QueryEncodable {
    var asQueryString: String { get }
}


extension Bool: QueryEncodable {
	public var asQueryString: String { self.description }
}

extension Int: QueryEncodable {
    public var asQueryString: String { self.description }
}

extension String: QueryEncodable {
    public var asQueryString: String { self }
}

extension UUID: QueryEncodable {
    public var asQueryString: String { self.uuidString }
}

extension Optional: QueryEncodable where Wrapped: QueryEncodable {
    public var asQueryString: String { self?.asQueryString ?? "nil" }
}
