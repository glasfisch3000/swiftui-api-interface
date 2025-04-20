import Foundation

@MainActor
public protocol ModelProtocol: AnyObject, Sendable, Identifiable where ID == UUID {
    associatedtype Properties: ModelProperties & Encodable & Sendable
    
    static nonisolated var scheme: String { get }
    
    var id: UUID! { get }
    var lastUpdated: Date? { get set }
    
    var properties: Properties { get set }
    nonisolated init(id: UUID, properties: Properties)
}

public protocol ModelProperties: Sendable, Decodable {
    func encode() -> [String: QueryEncodable]
}

extension ModelProperties {
    func encode() -> [String: QueryEncodable] {
        var result: [String: QueryEncodable] = [:]
        
        for (label, value) in Mirror(reflecting: self).children {
            guard let label = label else { continue }
            guard let value = value as? QueryEncodable else { continue }
            result[label] = value
        }
        
        return result
    }
}


