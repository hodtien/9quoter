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
}

struct ClientListResponse: Codable {
    let connections: [ClientConnection]
}

// MARK: - Usage / Quota

struct QuotaEntry: Codable {
    let used: Int
    let total: Int
    let remaining: Int
    let unlimited: Bool
    let resetAt: String?
    let remainingPercentage: Double?
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
}

// MARK: - View Model

struct ProviderQuota: Identifiable {
    let id: String
    let provider: String
    let name: String
    let isActive: Bool
    let plan: String
    let quotas: [(key: String, value: QuotaEntry)]
    let limitReached: Bool
    let priority: Int

    var displayName: String {
        name.isEmpty ? provider : name
    }

    var providerIconURL: String? {
        let known = ["claude", "github", "codex", "minimax", "gemini", "anthropic", "openai"]
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
        case let p where p.hasPrefix("minimax"): return "waveform"
        case let p where p.hasPrefix("anthropic"): return "brain"
        default: return "server.rack"
        }
    }

    var statusColor: String {
        if !isActive { return "gray" }
        if limitReached { return "red" }
        let minRemaining = quotas.compactMap { entry -> Int? in
            guard !entry.value.unlimited else { return nil }
            return entry.value.remaining * 100 / max(entry.value.total, 1)
        }.min() ?? 100
        if minRemaining <= 10 { return "red" }
        if minRemaining <= 30 { return "orange" }
        return "green"
    }
}
