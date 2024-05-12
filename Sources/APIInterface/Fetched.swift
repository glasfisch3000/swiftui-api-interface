import SwiftUI

@propertyWrapper
public struct Fetched<Source: Fetchable>: DynamicProperty {
    public typealias Value = Source.FetchedValue
    
    @State private var cachedValue: Value?
    @State private var error: Error?
    @State private var loadingTasks: [UUID: Task<Value, Error>]
    
    public var source: Source
    
    public init(source: Source) {
        self.source = source
        self._cachedValue = State(initialValue: nil)
        self._error = State(initialValue: nil)
        self._loadingTasks = State(initialValue: [:])
    }
    
    public var wrappedValue: FetchStatus<Value> {
        if let error = error {
            .error(error)
        } else if let value = cachedValue {
            .value(value)
        } else {
            .loading
        }
    }
    
    public var projectedValue: FetchStatus<FetchAdapter<Value>> {
        switch wrappedValue {
        case .loading: .loading
        case .error(let error): .error(error)
        case .value(let value): .value(FetchAdapter(wrappedValue: value, refresh: self.refresh))
        }
    }
    
    public var isLoading: Bool {
        !loadingTasks.isEmpty
    }
    
    public func update() {
        guard self.cachedValue == nil else { return }
        guard self.error == nil else { return }
        guard self.loadingTasks.isEmpty else { return }
        
        Task {
            await self.refresh()
        }
    }
    
    public func refresh() async {
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

extension Fetched where Source: FetchableWithConfiguration {
    public func refresh(with configuration: Source.Configuration) async {
        let uuid = UUID()
        
        // kickstart loading task
        let task = Task {
            try await source.fetch(with: configuration)
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

extension Fetched {
    public func reset() {
        self.cachedValue = nil
        self.error = nil
        
        for (uuid, loadingTask) in self.loadingTasks {
            loadingTask.cancel()
            loadingTasks.removeValue(forKey: uuid)
        }
    }
}
