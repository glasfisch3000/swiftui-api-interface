import Foundation

public protocol APIRequestSuite<API, Model> {
    associatedtype API: APIProtocol
    associatedtype Model: ModelProtocol
    
    associatedtype List: APIListRequestProtocol<API, Model>
    associatedtype Find: APIFindRequestProtocol<API, Model>
}

public protocol APIWritableRequestSuite<API, Model>: APIRequestSuite {
    associatedtype Create: APICreateRequestProtocol<API, Model>
    associatedtype Update: APIUpdateRequestProtocol<API, Model>
    associatedtype Delete: APIDeleteRequestProtocol<API, Model>
}


extension APIRequestSuite {
    public func list() -> List {
        .init()
    }
    
    public func find(id: UUID) -> Find {
        .init(id: id)
    }
}

extension APIWritableRequestSuite {
    public func create(properties: Model.Properties) -> Create {
        .init(properties: properties)
    }
    
    public func update(id: UUID, properties: Model.Properties) -> Update {
        .init(id: id, properties: properties)
    }
    
    public func delete(id: UUID) -> Delete {
        .init(id: id)
    }
}
