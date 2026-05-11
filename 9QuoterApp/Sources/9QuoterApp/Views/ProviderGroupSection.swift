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
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))

            Text("\(activeCount)/\(accounts.count)")
                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.38))
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(Color.white.opacity(0.065), in: Capsule())

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(Color(red: 0.11, green: 0.10, blue: 0.16))
        .zIndex(1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 6, y: 3)
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
        .padding(.top, 8)
        .padding(.bottom, 7)
    }
}
