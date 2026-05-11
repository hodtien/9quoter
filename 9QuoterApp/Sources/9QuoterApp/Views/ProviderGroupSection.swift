import SwiftUI

struct ProviderGroupHeader: View {
    let providerName: String
    let accounts: [ProviderQuota]
    let baseURL: String

    private var title: String {
        switch providerName {
        case let p where p.hasPrefix("github"): return "Github"
        case let p where p.hasPrefix("claude"): return "Claude"
        case let p where p.hasPrefix("codex"): return "Codex"
        case let p where p.hasPrefix("gemini"): return "Gemini"
        case let p where p.hasPrefix("minimax"): return "MiniMax"
        default: return providerName.capitalized
        }
    }

    private var representative: ProviderQuota? {
        accounts.first
    }

    private var activeCount: Int {
        accounts.filter(\.isActive).count
    }

    var body: some View {
        HStack(spacing: 8) {
            if let representative {
                ProviderIcon(provider: representative, baseURL: baseURL, size: 18)
            }

            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.86))

            Text("\(activeCount)/\(accounts.count)")
                .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.42))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08), in: Capsule())

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .background(Color(red: 0.10, green: 0.09, blue: 0.14).opacity(0.88))
    }
}

struct ProviderGroupSection: View {
    let accounts: [ProviderQuota]
    let baseURL: String
    let onToggle: (ProviderQuota, Bool) -> Void

    var body: some View {
        VStack(spacing: 5) {
            ForEach(accounts) { account in
                AccountQuotaCard(account: account, baseURL: baseURL) { isActive in
                    onToggle(account, isActive)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }
}
