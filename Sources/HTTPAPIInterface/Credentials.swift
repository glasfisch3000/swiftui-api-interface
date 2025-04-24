import Foundation

public struct Credentials: Sendable {
    public var username: String
    public var password: String
    
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
    
    public func makeHTTPBasicAuthorization() -> String {
        let auth = Data((username + ":" + password).utf8)
        return "Basic " + auth.base64EncodedString()
    }
}
