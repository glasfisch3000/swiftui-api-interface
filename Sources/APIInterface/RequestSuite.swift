import Foundation

public protocol APIRequestSuite<API, Model>: APIRequest {
    associatedtype Model: ModelProtocol
    
    associatedtype List: APIListRequest<API, Model> where List.Parent == Self
    associatedtype Find: APIFindRequest<API, Model> where Find.Parent == Self
    
    func list() -> List
    func find(id: UUID) -> Find
}

public protocol APIWritableRequestSuite<API, Model>: APIRequestSuite {
    associatedtype Create: APICreateRequest<API, Model> where Create.Parent == Self
    associatedtype Update: APIUpdateRequest<API, Model> where Update.Parent == Self
    associatedtype Delete: APIDeleteRequest<API, Model> where Delete.Parent == Self
    
    func create(properties: Model.Properties) -> Create
    func update(id: UUID, properties: Model.Properties) -> Update
    func delete(id: UUID) -> Delete
}
