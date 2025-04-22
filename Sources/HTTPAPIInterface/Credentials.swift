import Foundation

public struct Credentials: Sendable {
    public var username: String
    public var password: String
    
    public func makeHTTPBasicAuthorization() -> String {
        let auth = Data((username + ":" + password).utf8)
        return "Basic " + auth.base64EncodedString()
    }
}
