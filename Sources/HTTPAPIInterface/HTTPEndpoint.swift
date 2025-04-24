public struct HTTPEndpoint: Sendable {
    public enum Scheme: String, Sendable {
        case http, https
    }
    
    public var scheme: Scheme
    public var host: String
    public var port: UInt16
    public var path: [String]
    
    public init(scheme: Scheme, host: String, port: UInt16, path: [String] = []) {
        self.scheme = scheme
        self.host = host
        self.port = port
        self.path = path
    }
    
    public func makeURL(for request: HTTPAPI.RawRequest) -> String {
        let path = (self.path + request.path).joined(separator: "/")
        let query = request.query.compactMap {
            guard let key = $0.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let value = $0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return nil
            }
            return "\(key)=\(value)"
        }.joined(separator: "&")
        
        return "\(self.scheme)://\(self.host):\(self.port)/api/\(path)?\(query)"
    }
}
