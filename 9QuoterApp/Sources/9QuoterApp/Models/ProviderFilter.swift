import Foundation

struct ProviderFilterOption: Identifiable {
    enum ID: Hashable, Equatable {
        case all
        case provider(String)
    }

    let id: ID
    let title: String
    let count: Int
    let representative: ProviderQuota?

    static func == (lhs: ProviderFilterOption, rhs: ProviderFilterOption) -> Bool {
        lhs.id == rhs.id
    }

    static func visibleAccounts(_ accounts: [ProviderQuota], showInactive: Bool) -> [ProviderQuota] {
        showInactive ? accounts : accounts.filter(\.isActive)
    }

    static func options(for accounts: [ProviderQuota]) -> [ProviderFilterOption] {
        let grouped = Dictionary(grouping: accounts, by: providerKey(for:))
        let providerOptions = grouped
            .map { key, members in
                ProviderFilterOption(
                    id: .provider(key),
                    title: providerTitle(for: key),
                    count: members.count,
                    representative: members
                        .sorted { ($0.priority, $0.name) < ($1.priority, $1.name) }
                        .first
                )
            }
            .sorted { groupRank($0.keyString) < groupRank($1.keyString) }

        return [
            ProviderFilterOption(
                id: .all,
                title: "All",
                count: accounts.count,
                representative: nil
            )
        ] + providerOptions
    }

    static func filteredAccounts(
        _ accounts: [ProviderQuota],
        selectedProvider: String?,
        searchText: String
    ) -> [ProviderQuota] {
        let providerFiltered: [ProviderQuota]
        if let selectedProvider {
            providerFiltered = accounts.filter { providerKey(for: $0) == selectedProvider }
        } else {
            providerFiltered = accounts
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return providerFiltered }

        return providerFiltered.filter { account in
            account.provider.lowercased().contains(query)
                || account.name.lowercased().contains(query)
                || account.plan.lowercased().contains(query)
        }
    }

    static func resolvedSelection(selectedProvider: String?, options: [ProviderFilterOption]) -> String? {
        guard let selectedProvider else { return nil }
        let exists = options.contains { option in
            option.id == .provider(selectedProvider)
        }
        return exists ? selectedProvider : nil
    }

    static func providerKey(for provider: ProviderQuota) -> String {
        provider.provider.components(separatedBy: "-").first ?? provider.provider
    }

    static func providerTitle(for key: String) -> String {
        switch key {
        case let p where p.hasPrefix("github"): return "Github"
        case let p where p.hasPrefix("claude"): return "Claude"
        case let p where p.hasPrefix("codex"): return "Codex"
        case let p where p.hasPrefix("gemini"): return "Gemini"
        case let p where p.hasPrefix("minimax"): return "MiniMax"
        default: return key.capitalized
        }
    }

    static func groupRank(_ key: String) -> Int {
        switch key {
        case "claude": return 0
        case "github": return 1
        case "codex": return 2
        case "minimax": return 3
        case "gemini": return 4
        default: return 99
        }
    }

    private var keyString: String {
        switch id {
        case .all: return ""
        case .provider(let key): return key
        }
    }
}
