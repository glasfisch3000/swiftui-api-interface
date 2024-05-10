public enum FetchStatus<Value> {
    case value(Value)
    case error
    case loading
}
