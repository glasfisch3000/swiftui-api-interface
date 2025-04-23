import Foundation

@propertyWrapper
public struct Relation<Parent: ModelProtocol, Child: ModelProtocol, Request: APIRequestSuite>: Sendable where Request.Model == Child {
    public typealias ChildCache = Cache<Request.API, Child, Request>
    
    public var parent: Parent!
    public var idPath: KeyPath<Parent.Properties, UUID> & Sendable
    public var childCache: ChildCache!
    
    public init(parent: Parent? = nil, path: KeyPath<Parent.Properties, UUID> & Sendable, cache: ChildCache? = nil) {
        self.parent = parent
        self.idPath = path
        self.childCache = cache
    }
    
    @MainActor
    public var wrappedValue: Child? {
        childCache[parent.properties[keyPath: idPath]].value
    }
    
    @MainActor
    public var isLoading: Bool {
        childCache[parent.properties[keyPath: idPath]].loading
    }
    
    public var projectedValue: Self { self }
}
