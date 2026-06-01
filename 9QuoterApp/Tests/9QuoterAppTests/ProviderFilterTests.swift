import Testing
@testable import _QuoterApp

struct ProviderFilterTests {
    @Test("Builds all and provider options from visible accounts")
    func buildsProviderFilterOptions() {
        let accounts = [
            provider(id: "github-1", provider: "github", name: "Account 1", isActive: true),
            provider(id: "codex-1", provider: "codex", name: "a@example.com", isActive: true),
            provider(id: "codex-2", provider: "codex", name: "b@example.com", isActive: false)
        ]

        let options = ProviderFilterOption.options(for: accounts)

        #expect(options.map(\.id) == [.all, .provider("github"), .provider("codex")])
        #expect(options[0].title == "All")
        #expect(options[0].count == 3)
        #expect(options[1].title == "Github")
        #expect(options[1].count == 1)
        #expect(options[2].title == "Codex")
        #expect(options[2].count == 2)
        #expect(options[1].representative?.id == "github-1")
    }

    @Test("Applies selected provider before search")
    func appliesProviderSelectionBeforeSearch() {
        let accounts = [
            provider(id: "github-1", provider: "github", name: "codex notes", isActive: true),
            provider(id: "codex-1", provider: "codex", name: "main@example.com", isActive: true),
            provider(id: "codex-2", provider: "codex", name: "team@example.com", isActive: true)
        ]

        let filtered = ProviderFilterOption.filteredAccounts(
            accounts,
            selectedProvider: "codex",
            searchText: "team"
        )

        #expect(filtered.map(\.id) == ["codex-2"])
    }

    @Test("Searches all providers when all is selected")
    func searchesAllProviders() {
        let accounts = [
            provider(id: "github-1", provider: "github", name: "team", isActive: true),
            provider(id: "codex-1", provider: "codex", name: "team", isActive: true),
            provider(id: "codex-2", provider: "codex", name: "other", isActive: true)
        ]

        let filtered = ProviderFilterOption.filteredAccounts(
            accounts,
            selectedProvider: nil,
            searchText: "team"
        )

        #expect(filtered.map(\.id) == ["github-1", "codex-1"])
    }

    @Test("Hides inactive accounts before building options")
    func hidesInactiveAccountsBeforeOptions() {
        let accounts = [
            provider(id: "github-1", provider: "github", name: "Account 1", isActive: true),
            provider(id: "codex-1", provider: "codex", name: "Inactive", isActive: false)
        ]

        let visible = ProviderFilterOption.visibleAccounts(accounts, showInactive: false)
        let options = ProviderFilterOption.options(for: visible)

        #expect(visible.map(\.id) == ["github-1"])
        #expect(options.map(\.id) == [.all, .provider("github")])
    }

    private func provider(
        id: String,
        provider: String,
        name: String,
        isActive: Bool,
        plan: String = "plus",
        priority: Int = 0
    ) -> ProviderQuota {
        ProviderQuota(
            id: id,
            provider: provider,
            name: name,
            isActive: isActive,
            plan: plan,
            quotas: [],
            limitReached: false,
            priority: priority,
            message: nil,
            quotaUnavailable: false,
            isLoadingQuota: false
        )
    }
}
