import Foundation

enum LoginError: LocalizedError {
    case invalidPassword
    case noTokenInResponse
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidPassword: return "Invalid password"
        case .noTokenInResponse: return "Server did not return a token"
        case .network(let e): return e.localizedDescription
        }
    }
}

@MainActor
class RouterService: ObservableObject {
    @Published var providers: [ProviderQuota] = []
    @Published var isLoading = false
    @Published var isAuthenticated = false
    @Published var error: String?
    @Published var lastRefreshed: Date?

    var baseURL: String
    var authToken: String {
        didSet { isAuthenticated = !authToken.isEmpty }
    }

    private var refreshTask: Task<Void, Never>?

    init() {
        let savedURL = UserDefaults.standard.string(forKey: "baseURL") ?? "http://localhost:20128"
        let stored = KeychainStore.load(key: "authToken") ?? ""
        self.baseURL = savedURL
        self.authToken = stored
        self.isAuthenticated = !stored.isEmpty

        if !stored.isEmpty {
            let interval = UserDefaults.standard.double(forKey: "refreshInterval")
            Task { @MainActor in
                self.startAutoRefresh(interval: interval > 0 ? interval : 60)
            }
        }
    }

    func login(password: String) async throws {
        let url = URL(string: "\(baseURL)/api/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("locale=en", forHTTPHeaderField: "Cookie")
        request.httpBody = try JSONEncoder().encode(["password": password])

        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        let (data, response) = try await URLSession(configuration: config).data(for: request)

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["error"] != nil {
            throw LoginError.invalidPassword
        }

        guard let http = response as? HTTPURLResponse,
              let setCookie = http.value(forHTTPHeaderField: "Set-Cookie"),
              let token = extractAuthToken(from: setCookie), !token.isEmpty else {
            throw LoginError.noTokenInResponse
        }

        KeychainStore.save(token, key: "authToken")
        KeychainStore.save(password, key: "loginPassword")
        authToken = token
    }

    func logout() {
        KeychainStore.delete(key: "authToken")
        KeychainStore.delete(key: "loginPassword")
        authToken = ""
        providers = []
        stopAutoRefresh()
    }

    func refresh() async {
        guard !authToken.isEmpty else {
            error = "Not authenticated — please sign in"
            return
        }
        isLoading = true
        error = nil
        do {
            let clients = try await fetchClientsWithRetry()
            var results: [ProviderQuota] = []
            await withTaskGroup(of: ProviderQuota?.self) { group in
                for client in clients {
                    group.addTask {
                        try? await self.buildProviderQuota(client: client)
                    }
                }
                for await result in group {
                    if let r = result { results.append(r) }
                }
            }
            results.sort { ($0.priority, $0.name) < ($1.priority, $1.name) }
            providers = results
            lastRefreshed = Date()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func setAccount(_ account: ProviderQuota, isActive: Bool) async {
        guard !authToken.isEmpty else {
            error = "Not authenticated — please sign in"
            return
        }
        do {
            try await updateAccount(id: account.id, isActive: isActive)
            providers = providers.map { provider in
                guard provider.id == account.id else { return provider }
                return ProviderQuota(
                    id: provider.id,
                    provider: provider.provider,
                    name: provider.name,
                    isActive: isActive,
                    plan: provider.plan,
                    quotas: provider.quotas,
                    limitReached: provider.limitReached,
                    priority: provider.priority
                )
            }
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startAutoRefresh(interval: TimeInterval = 60) {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
    }

    // MARK: - Private

    private func extractAuthToken(from cookieString: String) -> String? {
        for part in cookieString.components(separatedBy: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("auth_token=") {
                return String(trimmed.dropFirst("auth_token=".count))
            }
        }
        return nil
    }

    private func fetchClientsWithRetry() async throws -> [ClientConnection] {
        do {
            return try await fetchClients()
        } catch {
            guard let password = KeychainStore.load(key: "loginPassword"), !password.isEmpty else {
                throw error
            }
            try await login(password: password)
            return try await fetchClients()
        }
    }

    private func fetchClients() async throws -> [ClientConnection] {
        let url = URL(string: "\(baseURL)/api/providers/client")!
        let data = try await get(url: url)
        return try JSONDecoder().decode(ClientListResponse.self, from: data).connections
    }

    private func updateAccount(id: String, isActive: Bool) async throws {
        let url = URL(string: "\(baseURL)/api/providers/\(id)")!
        let body = try JSONEncoder().encode(["isActive": isActive])
        try await sendJSON(url: url, method: "PUT", body: body)
    }

    private func buildProviderQuota(client: ClientConnection) async throws -> ProviderQuota {
        let url = URL(string: "\(baseURL)/api/usage/\(client.id)")!
        let data = try await get(url: url)
        let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
        let sortedQuotas = (usage.quotas ?? [:]).sorted { $0.key < $1.key }
        return ProviderQuota(
            id: client.id,
            provider: client.provider,
            name: client.name,
            isActive: client.isActive,
            plan: usage.plan ?? "unknown",
            quotas: sortedQuotas,
            limitReached: usage.limitReached ?? false,
            priority: client.priority ?? 99
        )
    }

    private func get(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("locale=en; auth_token=\(authToken)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw LoginError.invalidPassword
        }
        return data
    }

    private func sendJSON(url: URL, method: String, body: Data) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("locale=en; auth_token=\(authToken)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(baseURL, forHTTPHeaderField: "Origin")
        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            guard let password = KeychainStore.load(key: "loginPassword"), !password.isEmpty else {
                throw LoginError.invalidPassword
            }
            try await login(password: password)
            try await sendJSON(url: url, method: method, body: body)
        }
    }
}
