import Foundation
import Testing
@testable import _QuoterApp

@MainActor
struct RouterServiceRequestAuthTests {
    @Test("Applies Basic Auth header when credentials are configured")
    func appliesBasicAuthHeader() {
        var request = URLRequest(url: URL(string: "https://9router.karlorc.us/api/auth/login")!)
        let credentials = BasicAuthCredentials(username: "karl", password: "secret")

        RouterService.applyBasicAuth(credentials, to: &request)

        #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic a2FybDpzZWNyZXQ=")
    }

    @Test("Omits Basic Auth header when credentials are empty")
    func omitsBasicAuthHeaderWhenEmpty() {
        var request = URLRequest(url: URL(string: "https://9router.karlorc.us/api/auth/login")!)
        let credentials = BasicAuthCredentials(username: "", password: "")

        RouterService.applyBasicAuth(credentials, to: &request)

        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("Applies auth token cookie without replacing Basic Auth")
    func appliesAuthCookieWithoutReplacingBasicAuth() {
        var request = URLRequest(url: URL(string: "https://9router.karlorc.us/api/providers/client")!)
        let credentials = BasicAuthCredentials(username: "karl", password: "secret")

        RouterService.applyBasicAuth(credentials, to: &request)
        RouterService.applyAuthCookie(token: "token-123", to: &request)

        #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic a2FybDpzZWNyZXQ=")
        #expect(request.value(forHTTPHeaderField: "Cookie") == "locale=en; auth_token=token-123")
    }
}