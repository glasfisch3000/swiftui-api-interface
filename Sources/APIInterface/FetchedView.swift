import SwiftUI

public struct FetchedView<API: APIProtocol, Request: APIRequest, ErrorContent: View, LoadingContent: View, Content: View>: View where Request.API == API {
    @Fetched<API, Request> public var fetched: Request.Response?
    
    @ViewBuilder public var error: (API.APIError) -> ErrorContent
    @ViewBuilder public var loading: (_ isLoading: Bool) -> LoadingContent
    @ViewBuilder public var content: (Request.Response) -> Content
    
    public var body: some View {
        if let value = fetched {
            self.content(value)
        } else if let error = $fetched.apiError {
            self.error(error)
        } else {
            self.loading($fetched.isLoading)
        }
    }
}
