import Foundation

// MARK: - Auth

struct LoginResponse: Codable {
    let token: String?
    let error: String?
}

// MARK: - Provider / Client

struct ClientConnection: Codable, Identifiable {
    let id: String
    let provider: String
    let name: String
    let isActive: Bool
    let testStatus: String?
    let priority: Int?
    let email: String?
    let lastError: String?
    let expiresAt: String?
    let lastUsedAt: String?
}

struct ClientListResponse: Codable {
    let connections: [ClientConnection]
    let pagination: ClientListPagination?
    let providerOptions: [String]?
}

struct ClientListPagination: Codable {
    let page: Int
    let pageSize: Int
    let total: Int
    let totalPages: Int
}

// MARK: - Usage / Quota

struct QuotaEntry: Codable {
    let used: Double
    let total: Double
    let remaining: Double
    let unlimited: Bool
    let resetAt: String?
    let remainingPercentage: Double?

    var usedDisplay: String { formatNumber(used) }
    var totalDisplay: String { unlimited ? "Unlimited" : formatNumber(total) }
    var remainingDisplay: String { unlimited ? "Unlimited" : formatNumber(remaining) }

    private func formatNumber(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        let rounded = value.rounded()
        if value == rounded {
            return String(Int64(rounded))
        }
        return String(format: "%.2f", value)
    }
}

struct ExtraUsage: Codable {
    let isEnabled: Bool
    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
    }
}

struct UsageResponse: Codable {
    let plan: String?
    let resetDate: String?
    let limitReached: Bool?
    let quotas: [String: QuotaEntry]?
    let extraUsage: ExtraUsage?
    let reviewLimitReached: Bool?
    let message: String?
}

struct RecentUsageStatsResponse: Codable {
    static let displayLimit = 30

    let recentRequests: [RecentRequest]
    let totalRequests: Int?
    let totalPromptTokens: Int?
    let totalCompletionTokens: Int?
    let totalCost: Double?
}

struct RecentUsageChartPoint: Codable, Identifiable {
    let id = UUID()
    let label: String
    let tokens: Int
    let cost: Double

    enum CodingKeys: String, CodingKey {
        case label, tokens, cost
    }
}

enum RecentStatsPeriod: String, CaseIterable, Identifiable {
    case today
    case last24h = "24h"
    case last7d = "7d"
    case last30d = "30d"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "Today"
        case .last24h: return "24h"
        case .last7d: return "7D"
        case .last30d: return "30D"
        }
    }
}


struct RecentRequestMerger {
    static func merged(_ incoming: [RecentRequest], into existing: [RecentRequest]) -> [RecentRequest] {
        let combined = incoming + existing
        var seen = Set<String>()
        let unique = combined.filter { request in
            let minute = String(request.timestamp.prefix(16))
            let key = [request.model, request.provider, String(request.promptTokens), String(request.completionTokens), minute]
                .joined(separator: "|")
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
        return Array(unique.prefix(RecentUsageStatsResponse.displayLimit))
    }
}

struct RecentUsageStreamEvent: Codable {
    let recentRequests: [RecentRequest]?
    let totalRequests: Int?
    let totalPromptTokens: Int?
    let totalCompletionTokens: Int?
    let totalCost: Double?
}

struct RecentUsageStats {
    let totalRequests: Int
    let totalPromptTokens: Int
    let totalCompletionTokens: Int
    let totalCost: Double

    static let empty = RecentUsageStats(
        totalRequests: 0,
        totalPromptTokens: 0,
        totalCompletionTokens: 0,
        totalCost: 0
    )

    var requestsDisplay: String { Self.grouped(totalRequests) }
    var inputTokensDisplay: String { Self.grouped(totalPromptTokens) }
    var outputTokensDisplay: String { Self.grouped(totalCompletionTokens) }

    var costDisplay: String {
        let value = totalCost
        guard value.isFinite else { return "~$0.00" }
        return String(format: "~$%@", Self.grouped(value, fractionDigits: 2))
    }

    private static func grouped(_ value: Int) -> String {
        Self.formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func grouped(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

enum RecentStreamStatus {
    case idle
    case connecting
    case live
    case offline
}

struct RecentRequest: Codable, Identifiable {
    let id = UUID()
    let timestamp: String
    let model: String
    let provider: String
    let promptTokens: Int
    let completionTokens: Int
    let status: String

    var timestampDate: Date? {
        RecentRequest.dateFormatter.date(from: timestamp)
            ?? RecentRequest.fallbackDateFormatter.date(from: timestamp)
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    enum CodingKeys: String, CodingKey {
        case timestamp
        case model
        case provider
        case promptTokens
        case completionTokens
        case status
    }
}

// MARK: - View Model

enum PanelTab: String, CaseIterable, Identifiable {
    case quotas = "Quotas"
    case recent = "Usage"

    var id: String { rawValue }
}

enum QuotaAccountScope: String, CaseIterable, Identifiable {
    case active = "Active"
    case all = "All"

    var id: String { rawValue }
}

struct ProviderQuota: Identifiable {
    let id: String
    let provider: String
    let name: String
    let isActive: Bool
    let plan: String
    let quotas: [(key: String, value: QuotaEntry)]
    let limitReached: Bool
    let priority: Int
    let message: String?
    let quotaUnavailable: Bool
    let isLoadingQuota: Bool

    init(
        id: String,
        provider: String,
        name: String,
        isActive: Bool,
        plan: String,
        quotas: [(key: String, value: QuotaEntry)],
        limitReached: Bool,
        priority: Int,
        message: String?,
        quotaUnavailable: Bool,
        isLoadingQuota: Bool = false
    ) {
        self.id = id
        self.provider = provider
        self.name = name
        self.isActive = isActive
        self.plan = plan
        self.quotas = quotas
        self.limitReached = limitReached
        self.priority = priority
        self.message = message
        self.quotaUnavailable = quotaUnavailable
        self.isLoadingQuota = isLoadingQuota
    }

    var displayName: String {
        name.isEmpty ? provider : name
    }

    var clientConnection: ClientConnection {
        ClientConnection(
            id: id,
            provider: provider,
            name: name,
            isActive: isActive,
            testStatus: nil,
            priority: priority,
            email: nil,
            lastError: nil,
            expiresAt: nil,
            lastUsedAt: nil
        )
    }

    var providerIconURL: String? {
        let known = ["claude", "github", "codex", "kiro", "minimax", "gemini", "anthropic", "openai"]
        let base = provider.components(separatedBy: "-").first ?? provider
        guard known.contains(base) else { return nil }
        return "/providers/\(base).png"
    }

    var providerFallbackIcon: String {
        switch provider {
        case let p where p.hasPrefix("claude"): return "brain.head.profile"
        case let p where p.hasPrefix("github"): return "person.circle"
        case let p where p.hasPrefix("gemini"): return "sparkles"
        case let p where p.hasPrefix("codex"): return "chevron.left.forwardslash.chevron.right"
        case let p where p.hasPrefix("kiro"): return "shippingbox"
        case let p where p.hasPrefix("minimax"): return "waveform"
        case let p where p.hasPrefix("anthropic"): return "brain"
        default: return "server.rack"
        }
    }

    var statusColor: String {
        if !isActive || isLoadingQuota { return "gray" }
        if limitReached || quotaUnavailable { return "red" }
        let minRemaining = quotas.compactMap { entry -> Double? in
            guard !entry.value.unlimited else { return nil }
            if let remainingPercentage = entry.value.remainingPercentage {
                return remainingPercentage
            }
            return entry.value.remaining * 100 / max(entry.value.total, 1)
        }.min() ?? 100
        if minRemaining <= 10 { return "red" }
        if minRemaining <= 30 { return "orange" }
        return "green"
    }
}
