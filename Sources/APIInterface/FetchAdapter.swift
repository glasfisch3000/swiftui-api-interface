import SwiftUI

@propertyWrapper
public struct FetchAdapter<Value>: DynamicProperty {
    public var wrappedValue: Value
    public var refresh: () async -> ()
    
    public init(wrappedValue: Value, refresh: @escaping () async -> Void) {
        self.wrappedValue = wrappedValue
        self.refresh = refresh
    }
}

extension FetchAdapter {
    public var projectedValue: Self { self }
}
