import Foundation

@MainActor
public protocol ModelProtocol: AnyObject, Sendable, Identifiable where ID == UUID {
    associatedtype Properties: ModelProperties
    
    static nonisolated var scheme: String { get }
    
    var id: UUID { get }
    var lastUpdated: Date { get set }
    
    var properties: Properties { get set }
    nonisolated init(id: UUID, properties: Properties)
}
