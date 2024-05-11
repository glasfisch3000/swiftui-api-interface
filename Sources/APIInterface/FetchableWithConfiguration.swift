public protocol FetchableWithConfiguration: Fetchable {
    associatedtype FetchedValue
    associatedtype Configuration
    
    var defaultConfiguration: Configuration { get }
    func fetch(with configuration: Configuration) async throws -> FetchedValue
}

extension FetchableWithConfiguration {
    public func fetch() async throws -> FetchedValue {
        try await self.fetch(with: self.defaultConfiguration)
    }
}
