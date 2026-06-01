import Foundation

class SettingsStore: ObservableObject {
    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "baseURL") }
    }
    @Published var refreshInterval: Double {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }
    @Published var quotaAccountScope: QuotaAccountScope {
        didSet { UserDefaults.standard.set(quotaAccountScope.rawValue, forKey: "quotaAccountScope") }
    }

    // Token stored in Keychain, not UserDefaults
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
    }

    func clearToken() {
        KeychainStore.delete(key: "authToken")
        objectWillChange.send()
    }
}
