import Foundation

@MainActor
public protocol ModelProtocol: AnyObject, Sendable, Equatable, Identifiable where ID == UUID {
    associatedtype API: APIProtocol
    associatedtype Properties: ModelProperties
    
    static nonisolated var scheme: String { get }
    
    var id: UUID { get }
    var lastUpdated: Date { get set }
    
    var properties: Properties { get set }
    init(id: UUID, properties: Properties, cache: any CacheProtocol<API>)
}

extension ModelProtocol {
    nonisolated
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    
    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.properties < rhs.properties { return true }
        if rhs.properties < lhs.properties { return false }
        return lhs.id < rhs.id
    }
}


public protocol SoftDeletableModelProtocol: ModelProtocol where Properties: SoftDeletableModelProperties { }

extension SoftDeletableModelProtocol {
	public var isDeleted: Bool {
		self.properties.deleted != nil
	}
}
