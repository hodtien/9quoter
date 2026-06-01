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

class SettingsStore: ObservableObject {
    static let basicAuthUsernameKey = "basicAuthUsername"
    static let basicAuthPasswordKey = "basicAuthPassword"

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

    var basicAuthCredentials: BasicAuthCredentials {
        BasicAuthCredentials(username: basicAuthUsername, password: basicAuthPassword)
    }

    var authToken: String {
        get { KeychainStore.load(key: "authToken") ?? "" }
        set { KeychainStore.save(newValue, key: "authToken") }
    }

    init() {
        self.baseURL = UserDefaults.standard.string(forKey: "baseURL") ?? "http://localhost:20128"
        let saved = UserDefaults.standard.double(forKey: "refreshInterval")
        self.refreshInterval = saved > 0 ? saved : 60
        let savedScope = UserDefaults.standard.string(forKey: "quotaAccountScope")
        self.quotaAccountScope = savedScope.flatMap(QuotaAccountScope.init(rawValue:)) ?? .active
        self.basicAuthUsername = KeychainStore.load(key: Self.basicAuthUsernameKey) ?? ""
        self.basicAuthPassword = KeychainStore.load(key: Self.basicAuthPasswordKey) ?? ""
    }

    func setBasicAuth(username: String, password: String) {
        basicAuthUsername = username
        basicAuthPassword = password

        if username.isEmpty {
            KeychainStore.delete(key: Self.basicAuthUsernameKey)
        } else {
            KeychainStore.save(username, key: Self.basicAuthUsernameKey)
        }

        if password.isEmpty {
            KeychainStore.delete(key: Self.basicAuthPasswordKey)
        } else {
            KeychainStore.save(password, key: Self.basicAuthPasswordKey)
        }
    }

    func clearToken() {
        KeychainStore.delete(key: "authToken")
        objectWillChange.send()
    }
}
