import SwiftUI

@propertyWrapper
struct Fetched<Source: Fetchable>: DynamicProperty {
    typealias Value = Source.FetchedValue
    
    @State private var cachedValue: Value? = nil
    @State private var error: Error? = nil
    @State private var loadingTasks: [UUID: Task<Value, Error>] = [:]
    
    var source: Source
    
    init(source: Source) {
        self.source = source
    }
    
    var wrappedValue: FetchStatus<Value> {
        if error != nil {
            .error
        } else if let value = cachedValue {
            .value(value)
        } else {
            .loading
        }
    }
    
    func update() {
        guard self.cachedValue == nil else { return }
        guard self.error == nil else { return }
        guard self.loadingTasks.isEmpty else { return }
        
        Task {
            await self.refresh()
        }
    }
    
    func refresh() async {
        let uuid = UUID()
        
        // kickstart loading task
        let task = Task {
            try await source.fetch()
        }
        self.loadingTasks[uuid] = task
        
        // wait for result
        switch await task.result {
        case .success(let value):
            self.cachedValue = value
            self.error = nil
        case .failure(let error):
            self.error = error
        }
        
        // remove task from registry
        loadingTasks.removeValue(forKey: uuid)
    }
}
