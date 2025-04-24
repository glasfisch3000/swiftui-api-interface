import Foundation

public protocol APIRequestSuite<API, Model>: APIRequest {
    associatedtype Model: ModelProtocol
    
    associatedtype List: APIListRequest<API, Model> where List.Parent == Self
    associatedtype Find: APIFindRequest<API, Model> where Find.Parent == Self
}

public protocol APIWritableRequestSuite<API, Model>: APIRequestSuite {
    associatedtype Create: APICreateRequest<API, Model> where Create.Parent == Self
    associatedtype Update: APIUpdateRequest<API, Model> where Update.Parent == Self
    associatedtype Delete: APIDeleteRequest<API, Model> where Delete.Parent == Self
}


extension APIRequestSuite {
    public func list() -> List {
        .init(parent: self)
    }
    
    public func find(id: UUID) -> Find {
        .init(id: id, parent: self)
    }
}

extension APIWritableRequestSuite {
    public func create(properties: Model.Properties) -> Create {
        .init(properties: properties, parent: self)
    }
    
    public func update(id: UUID, properties: Model.Properties) -> Update {
        .init(id: id, properties: properties, parent: self)
    }
    
    public func delete(id: UUID) -> Delete {
        .init(id: id, parent: self)
    }
}
