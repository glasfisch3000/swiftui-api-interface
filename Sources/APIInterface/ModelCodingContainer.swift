import Foundation

public struct ModelCodingContainer<Model: ModelProtocol>: Sendable, Hashable, Encodable, Decodable {
    enum CodingKeys: CodingKey {
        case id
    }
    
    public var id: UUID
    public var properties: Model.Properties
    
    public init(id: UUID, properties: Model.Properties) {
        self.id = id
        self.properties = properties
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.properties = try .init(from: decoder)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try self.properties.encode(to: encoder)
    }
    
    public func encodeQuery() -> [String: QueryEncodable] {
        var query = properties.encodeQuery()
        query["id"] = id
        return query
    }
}
