import Testing
@testable import _QuoterApp

@Suite(.serialized)
struct SettingsStoreBasicAuthTests {
    init() {
        KeychainStore.delete(key: SettingsStore.basicAuthUsernameKey)
        KeychainStore.delete(key: SettingsStore.basicAuthPasswordKey)
    }

    @Test("Loads Basic Auth credentials from Keychain")
    func loadsBasicAuthCredentialsFromKeychain() {
        KeychainStore.save("karl", key: SettingsStore.basicAuthUsernameKey)
        KeychainStore.save("secret", key: SettingsStore.basicAuthPasswordKey)

        let settings = SettingsStore()

        #expect(settings.basicAuthUsername == "karl")
        #expect(settings.basicAuthPassword == "secret")
    }

    @Test("Saves Basic Auth credentials to Keychain")
    func savesBasicAuthCredentialsToKeychain() {
        let settings = SettingsStore()

        settings.setBasicAuth(username: "karl", password: "secret")

        #expect(KeychainStore.load(key: SettingsStore.basicAuthUsernameKey) == "karl")
        #expect(KeychainStore.load(key: SettingsStore.basicAuthPasswordKey) == "secret")
    }

    @Test("Clears Basic Auth credentials when fields are empty")
    func clearsBasicAuthCredentials() {
        KeychainStore.save("karl", key: SettingsStore.basicAuthUsernameKey)
        KeychainStore.save("secret", key: SettingsStore.basicAuthPasswordKey)
        let settings = SettingsStore()

        settings.setBasicAuth(username: "", password: "")

        #expect(settings.basicAuthUsername == "")
        #expect(settings.basicAuthPassword == "")
        #expect(KeychainStore.load(key: SettingsStore.basicAuthUsernameKey) == nil)
        #expect(KeychainStore.load(key: SettingsStore.basicAuthPasswordKey) == nil)
    }
}
