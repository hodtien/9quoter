import Testing
@testable import _QuoterApp

@Suite(.serialized)
struct SettingsStoreBasicAuthTests {
    final class FakeCredentialStore: CredentialStoring {
        private var values: [String: String] = [:]

        func load(key: String) -> String? {
            values[key]
        }

        func save(_ value: String, key: String) {
            values[key] = value
        }

        func delete(key: String) {
            values[key] = nil
        }
    }

    @Test("Loads Basic Auth credentials from injected storage")
    func loadsBasicAuthCredentialsFromInjectedStorage() {
        let credentialStore = FakeCredentialStore()
        credentialStore.save("karl", key: SettingsStore.basicAuthUsernameKey)
        credentialStore.save("secret", key: SettingsStore.basicAuthPasswordKey)

        let settings = SettingsStore(credentialStore: credentialStore)

        #expect(settings.basicAuthUsername == "karl")
        #expect(settings.basicAuthPassword == "secret")
    }

    @Test("Saves Basic Auth credentials to injected storage")
    func savesBasicAuthCredentialsToInjectedStorage() {
        let credentialStore = FakeCredentialStore()
        let settings = SettingsStore(credentialStore: credentialStore)

        settings.setBasicAuth(username: "karl", password: "secret")

        #expect(credentialStore.load(key: SettingsStore.basicAuthUsernameKey) == "karl")
        #expect(credentialStore.load(key: SettingsStore.basicAuthPasswordKey) == "secret")
    }

    @Test("Clears Basic Auth credentials when fields are empty")
    func clearsBasicAuthCredentials() {
        let credentialStore = FakeCredentialStore()
        credentialStore.save("karl", key: SettingsStore.basicAuthUsernameKey)
        credentialStore.save("secret", key: SettingsStore.basicAuthPasswordKey)
        let settings = SettingsStore(credentialStore: credentialStore)

        settings.setBasicAuth(username: "", password: "")

        #expect(settings.basicAuthUsername == "")
        #expect(settings.basicAuthPassword == "")
        #expect(credentialStore.load(key: SettingsStore.basicAuthUsernameKey) == nil)
        #expect(credentialStore.load(key: SettingsStore.basicAuthPasswordKey) == nil)
    }

    @Test("Trims whitespace-only usernames before persistence")
    func trimsWhitespaceOnlyUsernamesBeforePersistence() {
        let credentialStore = FakeCredentialStore()
        let settings = SettingsStore(credentialStore: credentialStore)

        settings.setBasicAuth(username: "  \n\t  ", password: "secret")

        #expect(settings.basicAuthUsername.isEmpty)
        #expect(credentialStore.load(key: SettingsStore.basicAuthUsernameKey) == nil)
        #expect(credentialStore.load(key: SettingsStore.basicAuthPasswordKey) == "secret")
    }
}
