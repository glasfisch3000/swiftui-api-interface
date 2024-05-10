protocol Fetchable {
    associatedtype FetchedValue
    
    func fetch() async throws -> FetchedValue
}
