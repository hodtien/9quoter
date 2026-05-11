import SwiftUI

@main
struct QuoterApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var service = RouterService()

    var body: some Scene {
        MenuBarExtra {
            MenubarContentView(service: service, settings: settings)
                .onAppear {
                    // Sync settings -> service on first appear
                    service.baseURL = settings.baseURL
                    service.authToken = settings.authToken
                    if service.isAuthenticated && service.providers.isEmpty {
                        service.startAutoRefresh(interval: settings.refreshInterval)
                    }
                }
        } label: {
            MenubarLabel(providers: service.providers, isAuthenticated: service.isAuthenticated)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenubarLabel: View {
    let providers: [ProviderQuota]
    let isAuthenticated: Bool

    private var worstColor: Color {
        guard isAuthenticated else { return .gray }
        let active = providers.filter(\.isActive)
        if active.isEmpty { return .gray }
        if active.contains(where: \.limitReached) { return .red }
        let colors = active.map(\.statusColor)
        if colors.contains("red") { return .red }
        if colors.contains("orange") { return .orange }
        return .green
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
            if isAuthenticated && !providers.isEmpty {
                Circle()
                    .fill(worstColor)
                    .frame(width: 6, height: 6)
            }
        }
    }
}
