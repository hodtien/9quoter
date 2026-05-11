import SwiftUI

struct MenubarContentView: View {
    @ObservedObject var service: RouterService
    @ObservedObject var settings: SettingsStore
    @State private var showSettings = false
    @State private var showInactive = true
    @State private var searchText = ""

    private var visibleProviders: [ProviderQuota] {
        let base = showInactive ? service.providers : service.providers.filter(\.isActive)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return base }
        return base.filter { provider in
            provider.provider.lowercased().contains(query)
                || provider.name.lowercased().contains(query)
                || provider.plan.lowercased().contains(query)
        }
    }

    private var groupedProviders: [(key: String, value: [ProviderQuota])] {
        let grouped = Dictionary(grouping: visibleProviders) { provider in
            provider.provider.components(separatedBy: "-").first ?? provider.provider
        }
        return grouped
            .map { ($0.key, $0.value.sorted { ($0.priority, $0.name) < ($1.priority, $1.name) }) }
            .sorted { groupRank($0.key) < groupRank($1.key) }
    }

    private func groupRank(_ key: String) -> Int {
        switch key {
        case "claude": return 0
        case "github": return 1
        case "codex": return 2
        case "minimax": return 3
        case "gemini": return 4
        default: return 99
        }
    }

    var body: some View {
        if !service.isAuthenticated {
            LoginView(service: service, settings: settings)
        } else {
            mainView
        }
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 10) {
                Text("CODEQUOTA")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.4))

                Spacer()

                if service.isLoading {
                    ProgressView().controlSize(.mini).tint(.white.opacity(0.4))
                } else if let last = service.lastRefreshed {
                    Text(last, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.25))
                }

                Button {
                    Task { await service.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .disabled(service.isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 10)

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
                TextField("Filter provider or account", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.72))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Error banner
            if let err = service.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 11))
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
            }

            // Content
            ZStack {
                // Always reserve space
                Color.clear.frame(height: 1)

                if service.isLoading && service.providers.isEmpty {
                    VStack(spacing: 10) {
                        ProgressView().tint(.white.opacity(0.4))
                        Text("Loading...")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)

                } else if service.providers.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: service.error != nil ? "exclamationmark.circle" : "chart.bar")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.2))
                        if let err = service.error {
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundStyle(.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        } else {
                            Text("No providers")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        Button("Retry") { Task { await service.refresh() } }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(.purple.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)

                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(groupedProviders, id: \.key) { group in
                                Section {
                                    ProviderGroupSection(accounts: group.value, baseURL: settings.baseURL) { account, isActive in
                                        Task { await service.setAccount(account, isActive: isActive) }
                                    }

                                    Divider()
                                        .background(Color.white.opacity(0.06))
                                        .padding(.horizontal, 12)
                                } header: {
                                    ProviderGroupHeader(providerName: group.key, accounts: group.value, baseURL: settings.baseURL)
                                }
                            }
                        }
                        .padding(.bottom, 150)
                    }
                    .frame(minHeight: 360, maxHeight: 860)
                }
            }

            // Footer
            HStack {
                Button {
                    showInactive.toggle()
                } label: {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(showInactive ? Color.purple.opacity(0.85) : Color.white.opacity(0.08))
                            .frame(width: 13, height: 13)
                            .overlay {
                                if showInactive {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        Text("Show inactive")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.34))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Settings") { showSettings = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.purple.opacity(0.8))

                Text("·").foregroundStyle(.white.opacity(0.2))

                Button("Logout") { service.logout() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.purple.opacity(0.8))

                Text("·").foregroundStyle(.white.opacity(0.2))

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.purple.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 590)
        .frame(minHeight: 520)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.10, green: 0.09, blue: 0.14))
        )
        .popover(isPresented: $showSettings) {
            SettingsView(settings: settings, service: service)
        }
        .onAppear {
            if service.providers.isEmpty {
                Task { await service.refresh() }
            }
        }
    }
}
