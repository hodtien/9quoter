import Foundation

struct BasicAuthCredentials: Equatable {
    let username: String
    let password: String

    var authorizationHeader: String? {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty, !password.isEmpty else { return nil }
        let raw = "\(trimmedUsername):\(password)"
        guard let data = raw.data(using: .utf8) else { return nil }
        return "Basic \(data.base64EncodedString())"
    }
}

protocol CredentialStoring {
    func load(key: String) -> String?
    func save(_ value: String, key: String)
    func delete(key: String)
}

struct KeychainCredentialStore: CredentialStoring {
    func load(key: String) -> String? {
        KeychainStore.load(key: key)
    }

    func save(_ value: String, key: String) {
        KeychainStore.save(value, key: key)
    }

    func delete(key: String) {
        KeychainStore.delete(key: key)
    }
}

class SettingsStore: ObservableObject {
    static let basicAuthUsernameKey = "basicAuthUsername"
    static let basicAuthPasswordKey = "basicAuthPassword"
    private static let authTokenKey = "authToken"

    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "baseURL") }
    }
    @Published var refreshInterval: Double {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }
    @Published var quotaAccountScope: QuotaAccountScope {
        didSet { UserDefaults.standard.set(quotaAccountScope.rawValue, forKey: "quotaAccountScope") }
    }
    @Published private(set) var basicAuthUsername: String
    @Published private(set) var basicAuthPassword: String

    private let credentialStore: CredentialStoring

    var basicAuthCredentials: BasicAuthCredentials {
        BasicAuthCredentials(username: basicAuthUsername, password: basicAuthPassword)
    }

    var authToken: String {
        get { credentialStore.load(key: Self.authTokenKey) ?? "" }
        set { credentialStore.save(newValue, key: Self.authTokenKey) }
    }

    init(credentialStore: CredentialStoring = KeychainCredentialStore()) {
        self.credentialStore = credentialStore
        self.baseURL = UserDefaults.standard.string(forKey: "baseURL") ?? "http://localhost:20128"
        let saved = UserDefaults.standard.double(forKey: "refreshInterval")
        self.refreshInterval = saved > 0 ? saved : 60
        let savedScope = UserDefaults.standard.string(forKey: "quotaAccountScope")
        self.quotaAccountScope = savedScope.flatMap(QuotaAccountScope.init(rawValue:)) ?? .active
        self.basicAuthUsername = credentialStore.load(key: Self.basicAuthUsernameKey) ?? ""
        self.basicAuthPassword = credentialStore.load(key: Self.basicAuthPasswordKey) ?? ""
    }

    func setBasicAuth(username: String, password: String) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        basicAuthUsername = trimmedUsername
        basicAuthPassword = password

        if trimmedUsername.isEmpty {
            credentialStore.delete(key: Self.basicAuthUsernameKey)
        } else {
            credentialStore.save(trimmedUsername, key: Self.basicAuthUsernameKey)
        }

        if password.isEmpty {
            credentialStore.delete(key: Self.basicAuthPasswordKey)
        } else {
            credentialStore.save(password, key: Self.basicAuthPasswordKey)
        }
    }

    func clearToken() {
        credentialStore.delete(key: Self.authTokenKey)
        objectWillChange.send()
    }
}
