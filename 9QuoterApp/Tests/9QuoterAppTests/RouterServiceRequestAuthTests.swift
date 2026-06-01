import Foundation
import Testing
@testable import _QuoterApp

@MainActor
struct RouterServiceRequestAuthTests {
    @Test("Applies Basic Auth header for HTTPS URL")
    func appliesBasicAuthForHTTPS() {
        var request = URLRequest(url: URL(string: "https://9router.karlorc.us/api/auth/login")!)
        let credentials = BasicAuthCredentials(username: "karl", password: "secret")

        RouterService.applyBasicAuth(credentials, to: &request)

        #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic a2FybDpzZWNyZXQ=")
    }

    @Test("Applies Basic Auth header for HTTP localhost")
    func appliesBasicAuthForLocalhost() {
        var request = URLRequest(url: URL(string: "http://localhost:20128/api/auth/login")!)
        let credentials = BasicAuthCredentials(username: "karl", password: "secret")

        RouterService.applyBasicAuth(credentials, to: &request)

        #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic a2FybDpzZWNyZXQ=")
    }

    @Test("Applies Basic Auth header for HTTP 127.0.0.1")
    func appliesBasicAuthFor127() {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:20128/api/auth/login")!)
        let credentials = BasicAuthCredentials(username: "karl", password: "secret")

        RouterService.applyBasicAuth(credentials, to: &request)

        #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic a2FybDpzZWNyZXQ=")
    }

    @Test("Applies Basic Auth header for HTTP IPv6 loopback")
    func appliesBasicAuthForIPv6Loopback() {
        var request = URLRequest(url: URL(string: "http://[::1]:20128/api/auth/login")!)
        let credentials = BasicAuthCredentials(username: "karl", password: "secret")

        RouterService.applyBasicAuth(credentials, to: &request)

        #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic a2FybDpzZWNyZXQ=")
    }

    @Test("Omits Basic Auth header for HTTP remote host")
    func omitsBasicAuthForRemoteHTTP() {
        var request = URLRequest(url: URL(string: "http://9router.karlorc.us/api/auth/login")!)
        let credentials = BasicAuthCredentials(username: "karl", password: "secret")

        RouterService.applyBasicAuth(credentials, to: &request)

        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
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

@MainActor
struct RouterServiceSyncTests {
    final class InMemoryCredentialStore: CredentialStoring {
        private var values: [String: String] = [:]

        func load(key: String) -> String? { values[key] }
        func save(_ value: String, key: String) { values[key] = value }
        func delete(key: String) { values[key] = nil }
    }

    @Test("syncBasicAuthCredentials updates internal credentials")
    func syncUpdatesCredentials() {
        let store = InMemoryCredentialStore()
        let service = RouterService(credentialStore: store)

        service.syncBasicAuthCredentials(BasicAuthCredentials(username: "alice", password: "pw123"))

        #expect(service.basicAuthCredentials.username == "alice")
        #expect(service.basicAuthCredentials.password == "pw123")
    }

    @Test("syncBasicAuthCredentials without arg reloads from store")
    func syncReloadsFromStore() {
        let store = InMemoryCredentialStore()
        store.save("bob", key: SettingsStore.basicAuthUsernameKey)
        store.save("hunter2", key: SettingsStore.basicAuthPasswordKey)
        let service = RouterService(credentialStore: store)

        service.syncBasicAuthCredentials()

        #expect(service.basicAuthCredentials.username == "bob")
        #expect(service.basicAuthCredentials.password == "hunter2")
    }

    @Test("init with injected store uses it for credentials")
    func initWithInjectedStoreLoadsCredentials() {
        let store = InMemoryCredentialStore()
        store.save("carol", key: SettingsStore.basicAuthUsernameKey)
        store.save("s3cr3t", key: SettingsStore.basicAuthPasswordKey)

        let service = RouterService(credentialStore: store)

        #expect(service.basicAuthCredentials.username == "carol")
        #expect(service.basicAuthCredentials.password == "s3cr3t")
    }

    @Test("reloadBasicAuthCredentials calls sync")
    func reloadCallsSync() {
        let store = InMemoryCredentialStore()
        store.save("dave", key: SettingsStore.basicAuthUsernameKey)
        store.save("pass987", key: SettingsStore.basicAuthPasswordKey)
        let service = RouterService(credentialStore: store)

        service.reloadBasicAuthCredentials()

        #expect(service.basicAuthCredentials.username == "dave")
        #expect(service.basicAuthCredentials.password == "pass987")
    }
}
