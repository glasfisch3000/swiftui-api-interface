struct BlankFetchable<FetchedValue>: Fetchable {
    private var fetcher: () async throws -> FetchedValue
    
    init(fetch: @escaping () -> FetchedValue) {
        self.fetcher = fetch
    }
    
    func fetch() async throws -> FetchedValue {
        try await self.fetcher()
    }
}
