public enum FetchStatus<Value> {
    case value(Value)
    case error(Error)
    case loading
}
