public struct BlankFetchable<FetchedValue>: Fetchable {
    private var fetcher: () async throws -> FetchedValue
    
    public init(fetch: @escaping () -> FetchedValue) {
        self.fetcher = fetch
    }
    
    public func fetch() async throws -> FetchedValue {
        try await self.fetcher()
    }
}
