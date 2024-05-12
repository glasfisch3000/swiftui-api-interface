import SwiftUI

@propertyWrapper
public struct Fetched<Source: Fetchable>: DynamicProperty {
    public typealias Value = Source.FetchedValue
    
    @State private var cachedValue: Value? = nil
    @State private var error: Error? = nil
    @State private var loadingTasks: [UUID: Task<Value, Error>] = [:]
    
    public var source: Source
    
    public init(source: Source) {
        self.source = source
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
    public var projectedValue: FetchAdapter<Value>? {
        guard case .value(let value) = self.wrappedValue else { return nil }
        return .init(wrappedValue: value, refresh: self.refresh)
    }
}
