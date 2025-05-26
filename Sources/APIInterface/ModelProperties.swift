import Foundation

public protocol ModelProperties: Sendable, Hashable, Encodable, Decodable {
    associatedtype CodingKeys: CodingKey
    
    var isValid: Bool { get }
    func encodeQuery() -> [String: QueryEncodable]
    
    static func < (lhs: Self, rhs: Self) -> Bool
}

extension ModelProperties {
    public func encodeQuery() -> [String: QueryEncodable] {
        var result: [String: QueryEncodable] = [:]
        
        for (label, value) in Mirror(reflecting: self).children {
            guard let label = label else { continue }
            guard let value = value as? QueryEncodable else { continue }
            result[label] = value
        }
        
        return result
    }
}



public protocol SoftDeletableModelProperties: ModelProperties {
	var deleted: Date? { get set }
}

extension SoftDeletableModelProperties {
	public func encodeQuery() -> [String: QueryEncodable] {
		var result: [String: QueryEncodable] = [:]
		
		for (label, value) in Mirror(reflecting: self).children {
			guard let label = label else { continue }
			if label == "deleted" { continue }
			
			guard let value = value as? QueryEncodable else { continue }
			result[label] = value
		}
		
		return result
	}
}
