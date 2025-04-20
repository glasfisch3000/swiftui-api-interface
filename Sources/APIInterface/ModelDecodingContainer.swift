import Foundation

public struct ModelDecodingContainer<Model: ModelProtocol>: Sendable, Decodable {
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
    
    public func makeModel() -> Model {
        Model(id: id, properties: properties)
    }
}

extension ModelProtocol {
    public typealias DecodingContainer = ModelDecodingContainer<Self>
}
