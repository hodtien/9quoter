import Foundation

enum LoginError: LocalizedError {
    case invalidPassword
    case noTokenInResponse
    case network(Error)
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .invalidPassword: return "Invalid password"
        case .noTokenInResponse: return "Server did not return a token"
        case .network(let e): return e.localizedDescription
        case .authenticationFailed: return "Check Basic Auth credentials or 9router password"
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
    @Published var quotaAccountScope: QuotaAccountScope = .active
    @Published var nextRefreshAt: Date?
    @Published var recentRequests: [RecentRequest] = []
    @Published var recentStats: RecentUsageStats = .empty
    @Published var recentStatsPeriod: RecentStatsPeriod = .today
    @Published var recentChartPoints: [RecentUsageChartPoint] = []
    @Published var recentRequestsError: String?
    @Published var isLoadingRecentRequests = false
    @Published var recentStreamStatus: RecentStreamStatus = .idle

    var hasLoadedProviders: Bool {
        lastRefreshed != nil || !providers.isEmpty
    }

    var baseURL: String
    var basicAuthCredentials: BasicAuthCredentials

    private let credentialStore: CredentialStoring
    var authToken: String {
        didSet {
            isAuthenticated = !authToken.isEmpty
            if authToken.isEmpty {
                stopAutoRefresh()
            }
        }
    }

    private var refreshTask: Task<Void, Never>?
    private var recentStreamTask: Task<Void, Never>?
    private var autoRefreshGeneration = 0
    private var lastStatsRefresh = Date.distantPast
    private var recentStatsGeneration = 0

    init(credentialStore: CredentialStoring = KeychainCredentialStore()) {
        let savedURL = UserDefaults.standard.string(forKey: "baseURL") ?? "http://localhost:20128"
        let stored = credentialStore.load(key: "authToken") ?? ""
        self.baseURL = savedURL
        self.authToken = stored
        self.isAuthenticated = !stored.isEmpty
        self.credentialStore = credentialStore
        self.basicAuthCredentials = BasicAuthCredentials(username: "", password: "")
        syncBasicAuthCredentials()
        // quotaAccountScope is owned by SettingsStore and synced in on appear.
    }

    func syncBasicAuthCredentials() {
        syncBasicAuthCredentials(BasicAuthCredentials(
            username: credentialStore.load(key: SettingsStore.basicAuthUsernameKey) ?? "",
            password: credentialStore.load(key: SettingsStore.basicAuthPasswordKey) ?? ""
        ))
    }

    func syncBasicAuthCredentials(_ credentials: BasicAuthCredentials) {
        basicAuthCredentials = credentials
    }

    func reloadBasicAuthCredentials() {
        syncBasicAuthCredentials()
    }

    func login(password: String) async throws {
        let url = URL(string: "\(baseURL)/api/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("locale=en", forHTTPHeaderField: "Cookie")
        Self.applyBasicAuth(basicAuthCredentials, to: &request)
        request.httpBody = try JSONEncoder().encode(["password": password])

        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        let (data, response) = try await URLSession(configuration: config).data(for: request)

        if let http = response as? HTTPURLResponse,
           http.statusCode == 401,
           basicAuthCredentials.authorizationHeader != nil {
            throw LoginError.authenticationFailed
        }

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
        stopRecentStream()
        authToken = ""
        providers = []
        recentRequests = []
        recentStats = .empty
        recentRequestsError = nil
        stopAutoRefresh()
    }

    func refresh() async {
        guard !authToken.isEmpty else {
            error = "Not authenticated — please sign in"
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let clients = try await fetchClientsWithRetry()
            let scopedClients = quotaAccountScope == .active ? clients.filter(\.isActive) : clients
            if providers.isEmpty {
                providers = placeholderProviderQuotas(for: scopedClients)
            }
            let quotas = await fetchProviderQuotas(for: scopedClients)
            providers = quotas.sorted { ($0.priority, $0.name) < ($1.priority, $1.name) }
            lastRefreshed = Date()
        } catch {
            self.error = error.localizedDescription
        }
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
                    priority: provider.priority,
                    message: provider.message,
                    quotaUnavailable: provider.quotaUnavailable,
                    iconURL: provider.iconURL
                )
            }
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshAccount(_ account: ProviderQuota) async {
        guard !authToken.isEmpty else {
            error = "Not authenticated — please sign in"
            return
        }
        providers = providers.map { provider in
            guard provider.id == account.id else { return provider }
            return ProviderQuota(
                id: provider.id,
                provider: provider.provider,
                name: provider.name,
                isActive: provider.isActive,
                plan: provider.plan,
                quotas: provider.quotas,
                limitReached: provider.limitReached,
                priority: provider.priority,
                message: provider.message,
                quotaUnavailable: provider.quotaUnavailable,
                isLoadingQuota: true,
                iconURL: provider.iconURL
            )
        }
        do {
            let refreshed = try await buildProviderQuota(client: account.clientConnection)
            providers = providers.map { provider in
                provider.id == account.id ? refreshed : provider
            }
            lastRefreshed = Date()
        } catch {
            providers = providers.map { provider in
                guard provider.id == account.id else { return provider }
                return ProviderQuota(
                    id: provider.id,
                    provider: provider.provider,
                    name: provider.name,
                    isActive: provider.isActive,
                    plan: provider.plan,
                    quotas: provider.quotas,
                    limitReached: provider.limitReached,
                    priority: provider.priority,
                    message: nil,
                    quotaUnavailable: true,
                    iconURL: provider.iconURL
                )
            }
            self.error = error.localizedDescription
        }
    }

    func setQuotaAccountScope(_ scope: QuotaAccountScope) async {
        quotaAccountScope = scope
        await refresh()
    }

    func startAutoRefresh(interval: TimeInterval = 60) {
        autoRefreshGeneration += 1
        let generation = autoRefreshGeneration
        refreshTask?.cancel()
        nextRefreshAt = nil
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()

            while !Task.isCancelled, self.autoRefreshGeneration == generation {
                self.nextRefreshAt = Date().addingTimeInterval(interval)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled, self.autoRefreshGeneration == generation else { break }
                self.nextRefreshAt = nil
                await self.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshGeneration += 1
        refreshTask?.cancel()
        refreshTask = nil
        nextRefreshAt = nil
    }

    func startRecentStream() {
        guard !authToken.isEmpty else {
            recentRequestsError = "Not authenticated — please sign in"
            recentStreamStatus = .offline
            return
        }
        guard recentStreamTask == nil else { return }

        recentRequestsError = nil
        recentStreamStatus = .connecting
        isLoadingRecentRequests = recentRequests.isEmpty
        recentStreamTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isLoadingRecentRequests = false
                if !Task.isCancelled {
                    self.recentStreamStatus = .offline
                    self.recentStreamTask = nil
                }
            }
            do {
                let snapshot = try await self.fetchRecentRequests()
                guard !Task.isCancelled else { return }
                self.recentRequests = snapshot
                self.isLoadingRecentRequests = false
                try await self.consumeRecentStream()
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                self.recentRequestsError = "Recent requests unavailable"
                self.recentStreamStatus = .offline
            }
        }
    }

    func stopRecentStream() {
        recentStreamTask?.cancel()
        recentStreamTask = nil
        recentStreamStatus = .idle
        isLoadingRecentRequests = false
    }

    func setRecentStatsPeriod(_ period: RecentStatsPeriod) async {
        guard period != recentStatsPeriod else { return }
        recentStatsPeriod = period
        recentStatsGeneration += 1
        await refreshRecentStats()
        await refreshRecentChart()
    }

    func refreshRecentStats() async {
        guard !authToken.isEmpty else { return }
        let generation = recentStatsGeneration
        let period = recentStatsPeriod
        guard let url = URL(string: "\(baseURL)/api/usage/stats?period=\(period.rawValue)") else { return }
        do {
            let data = try await get(url: url)
            guard generation == recentStatsGeneration else { return }
            let response = try JSONDecoder().decode(RecentUsageStatsResponse.self, from: data)
            applySnapshotStats(response)
        } catch {
            // Keep last known stats on transient errors
        }
    }

    func refreshRecentChart() async {
        guard !authToken.isEmpty else { return }
        let generation = recentStatsGeneration
        let period = recentStatsPeriod
        guard let url = URL(string: "\(baseURL)/api/usage/chart?period=\(period.rawValue)") else { return }
        do {
            let data = try await get(url: url)
            guard generation == recentStatsGeneration else { return }
            let points = try JSONDecoder().decode([RecentUsageChartPoint].self, from: data)
            recentChartPoints = points
        } catch {
            // Keep last known chart on transient errors
        }
    }

    // MARK: - Static Helpers

    static func applyBasicAuth(_ credentials: BasicAuthCredentials, to request: inout URLRequest) {
        guard let header = credentials.authorizationHeader else { return }
        guard isLocalOrSecure(request.url) else { return }
        request.setValue(header, forHTTPHeaderField: "Authorization")
    }

    private static func isLocalOrSecure(_ url: URL?) -> Bool {
        guard let url else { return false }
        if url.scheme == "https" { return true }
        guard url.scheme == "http" else { return false }
        let host = url.host ?? ""
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    static func applyAuthCookie(token: String, to request: inout URLRequest) {
        request.setValue("locale=en; auth_token=\(token)", forHTTPHeaderField: "Cookie")
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
        let pageSize = 100
        let firstPage = try await fetchClientsPage(page: 1, pageSize: pageSize)
        guard let totalPages = firstPage.pagination?.totalPages, totalPages > 1 else {
            return firstPage.connections
        }

        var clients = firstPage.connections
        for page in 2...totalPages {
            let response = try await fetchClientsPage(page: page, pageSize: pageSize)
            clients.append(contentsOf: response.connections)
        }
        return clients
    }

    private func fetchClientsPage(page: Int, pageSize: Int) async throws -> ClientListResponse {
        let url = URL(string: "\(baseURL)/api/providers/client?page=\(page)&pageSize=\(pageSize)&accountStatus=all&sort=priority")!
        let data = try await get(url: url)
        return try JSONDecoder().decode(ClientListResponse.self, from: data)
    }

    private func updateAccount(id: String, isActive: Bool) async throws {
        guard let url = URL(string: "\(baseURL)/api/providers/\(id)") else {
            throw LoginError.network(URLError(.badURL))
        }
        let body = try JSONEncoder().encode(["isActive": isActive])
        try await sendJSON(url: url, method: "PUT", body: body)
    }

    private func placeholderProviderQuotas(for clients: [ClientConnection]) -> [ProviderQuota] {
        clients
            .map { client in
                ProviderQuota(
                    id: client.id,
                    provider: client.provider,
                    name: client.name,
                    isActive: client.isActive,
                    plan: "checking",
                    quotas: [],
                    limitReached: false,
                    priority: client.priority ?? 99,
                    message: "Checking quota...",
                    quotaUnavailable: false,
                    isLoadingQuota: true,
                    iconURL: client.iconURL
                )
            }
            .sorted { ($0.priority, $0.name) < ($1.priority, $1.name) }
    }

    private func fetchProviderQuotas(for clients: [ClientConnection]) async -> [ProviderQuota] {
        var results: [ProviderQuota] = []
        await withTaskGroup(of: ProviderQuota.self) { group in
            for client in clients {
                group.addTask {
                    do {
                        return try await self.buildProviderQuota(client: client)
                    } catch {
                        return ProviderQuota(
                            id: client.id,
                            provider: client.provider,
                            name: client.name,
                            isActive: client.isActive,
                            plan: "unknown",
                            quotas: [],
                            limitReached: false,
                            priority: client.priority ?? 99,
                            message: nil,
                            quotaUnavailable: true,
                            iconURL: client.iconURL
                        )
                    }
                }
            }
            for await result in group {
                results.append(result)
            }
        }
        return results
    }

    private func fetchRecentRequests() async throws -> [RecentRequest] {
        guard let url = URL(string: "\(baseURL)/api/usage/stats?period=\(recentStatsPeriod.rawValue)") else {
            throw LoginError.network(URLError(.badURL))
        }
        let data = try await get(url: url)
        let response = try JSONDecoder().decode(RecentUsageStatsResponse.self, from: data)
        applySnapshotStats(response)
        return limitedRecentRequests(response.recentRequests)
    }

    private func applySnapshotStats(_ response: RecentUsageStatsResponse) {
        guard let totalRequests = response.totalRequests else { return }
        recentStats = RecentUsageStats(
            totalRequests: totalRequests,
            totalPromptTokens: response.totalPromptTokens ?? 0,
            totalCompletionTokens: response.totalCompletionTokens ?? 0,
            totalCost: response.totalCost ?? 0
        )
    }

    private func consumeRecentStream() async throws {
        let url = URL(string: "\(baseURL)/api/usage/stream")!
        var request = URLRequest(url: url)
        Self.applyAuthCookie(token: authToken, to: &request)
        Self.applyBasicAuth(basicAuthCredentials, to: &request)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let (lines, response) = try await URLSession.shared.bytes(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw LoginError.invalidPassword
        }
        recentStreamStatus = .live

        for try await line in lines.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespacesAndNewlines)
            guard payload != "[DONE]", let data = payload.data(using: .utf8) else { continue }
            guard let event = try? JSONDecoder().decode(RecentUsageStreamEvent.self, from: data) else { continue }
            if let recentRequests = event.recentRequests {
                self.recentRequests = RecentRequestMerger.merged(recentRequests, into: self.recentRequests)
                recentRequestsError = nil
                recentStreamStatus = .live
                scheduleStatsRefreshFromStream()
            }
        }
    }

    private func scheduleStatsRefreshFromStream() {
        let now = Date()
        guard now.timeIntervalSince(lastStatsRefresh) >= 4 else { return }
        lastStatsRefresh = now
        Task { [weak self] in await self?.refreshRecentStats() }
    }

    private func limitedRecentRequests(_ requests: [RecentRequest]) -> [RecentRequest] {
        Array(requests.prefix(RecentUsageStatsResponse.displayLimit))
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
            priority: client.priority ?? 99,
            message: usage.message,
            quotaUnavailable: false,
            iconURL: client.iconURL
        )
    }

    private func get(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        Self.applyAuthCookie(token: authToken, to: &request)
        Self.applyBasicAuth(basicAuthCredentials, to: &request)
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
        Self.applyAuthCookie(token: authToken, to: &request)
        Self.applyBasicAuth(basicAuthCredentials, to: &request)
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
