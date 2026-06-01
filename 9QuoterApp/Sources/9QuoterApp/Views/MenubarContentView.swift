import SwiftUI
import Charts

struct MenubarContentView: View {
    @ObservedObject var service: RouterService
    @ObservedObject var settings: SettingsStore
    @State private var showSettings = false
    @State private var showInactive = true
    @State private var searchText = ""
    @State private var selectedTab: PanelTab = .quotas
    @State private var recentChartRefreshTask: Task<Void, Never>?

    private func refreshCountdownText(now: Date) -> String? {
        guard selectedTab == .quotas, let nextRefreshAt = service.nextRefreshAt else { return nil }
        let seconds = max(0, Int(nextRefreshAt.timeIntervalSince(now).rounded(.up)))
        if seconds >= 60 {
            return "refresh in \(seconds / 60)m \(seconds % 60)s"
        }
        return "refresh in \(seconds)s"
    }

    private var recentStatusText: String? {
        guard selectedTab == .recent else { return nil }
        switch service.recentStreamStatus {
        case .idle: return nil
        case .connecting: return "connecting..."
        case .live: return "live"
        case .offline: return "offline"
        }
    }

    private var recentStatusColor: Color {
        switch service.recentStreamStatus {
        case .live: return .green.opacity(0.62)
        case .offline: return .orange.opacity(0.68)
        default: return .white.opacity(0.25)
        }
    }

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

    private func startQuotaRefreshIfNeeded() {
        let interval = UserDefaults.standard.double(forKey: "refreshInterval")
        service.startAutoRefresh(interval: interval > 0 ? interval : 60)
    }

    private func selectTab(_ tab: PanelTab) {
        selectedTab = tab
        switch tab {
        case .quotas:
            recentChartRefreshTask?.cancel()
            recentChartRefreshTask = nil
            service.stopRecentStream()
            startQuotaRefreshIfNeeded()
        case .recent:
            service.stopAutoRefresh()
            service.startRecentStream()
            recentChartRefreshTask?.cancel()
            recentChartRefreshTask = Task { await service.refreshRecentChart() }
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
            ZStack {
                // Centered tab cluster — absolute center, independent of edge content width
                HStack(spacing: 2) {
                    ForEach(PanelTab.allCases, id: \.self) { tab in
                        Button {
                            selectTab(tab)
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(selectedTab == tab ? .white.opacity(0.85) : .white.opacity(0.36))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 5)
                                .background(
                                    selectedTab == tab ? Color.purple.opacity(0.34) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 7)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))

                // Edge content — title left, status/refresh right
                HStack(spacing: 10) {
                    Text("9Quoter")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.4))

                    Spacer()

                    if service.isLoading && selectedTab == .quotas {
                        ProgressView().controlSize(.mini).tint(.white.opacity(0.4))
                    } else if let recentStatusText {
                        Text(recentStatusText)
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(recentStatusColor)
                    } else {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            if let refreshCountdownText = refreshCountdownText(now: context.date) {
                                Text(refreshCountdownText)
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.34))
                            }
                        }
                    }

                    Button {
                        if selectedTab == .quotas {
                            Task { await service.refresh() }
                        } else {
                            service.startRecentStream()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedTab == .quotas ? service.isLoading : service.recentStreamStatus == .connecting)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)


            if selectedTab == .quotas {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.34))
                    TextField(text: $searchText, prompt: Text("Filter provider or account").foregroundColor(.white.opacity(0.36))) { EmptyView() }
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.78))
                        .tint(.purple.opacity(0.85))
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.34))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }

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
            if selectedTab == .quotas {
                quotasContent
            } else {
                recentContent
            }

            // Footer
            HStack {
                if selectedTab == .quotas {
                    Button { @MainActor in
                        let nextShowInactive = !showInactive
                        showInactive = nextShowInactive
                        let scope: QuotaAccountScope = nextShowInactive ? .all : .active
                        settings.quotaAccountScope = scope
                        Task { await service.setQuotaAccountScope(scope) }
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
                                .foregroundStyle(.white.opacity(0.46))
                        }
                    }
                    .buttonStyle(.plain)
                }

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
        .frame(width: 670)
        .frame(height: 640)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.10, green: 0.09, blue: 0.14))
        )
        .popover(isPresented: $showSettings) {
            SettingsView(settings: settings, service: service)
        }
        .onAppear {
            showInactive = settings.quotaAccountScope == .all
            if selectedTab == .quotas {
                startQuotaRefreshIfNeeded()
            } else {
                service.startRecentStream()
            }
        }
        .onDisappear {
            service.stopAutoRefresh()
            service.stopRecentStream()
        }
    }

    private var quotasContent: some View {
        ZStack {
            // Always reserve space
            Color.clear.frame(height: 1)

            if service.isLoading && service.providers.isEmpty {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small).tint(.white.opacity(0.42))
                        Text("Loading accounts...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.46))
                    }

                    VStack(spacing: 7) {
                        ForEach(0..<4, id: \.self) { index in
                            QuotaAccountSkeletonRow(index: index)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .frame(maxWidth: .infinity)
                .frame(height: 260)

            } else if service.providers.isEmpty {
                emptyQuotaState

            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedProviders, id: \.key) { group in
                            Section {
                                ProviderGroupSection(
                                    accounts: group.value,
                                    baseURL: settings.baseURL,
                                    onRefresh: { account in
                                        Task { await service.refreshAccount(account) }
                                    }
                                ) { account, isActive in
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
    }

    private var emptyQuotaState: some View {
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
                    .foregroundStyle(.white.opacity(0.34))
            }
            Button("Retry") { startQuotaRefreshIfNeeded() }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.purple.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    private var recentContent: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                recentStatsColumn
                    .frame(width: 262)
                recentListColumn
            }
            RecentUsageChartView(points: service.recentChartPoints)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var recentStatsColumn: some View {
        VStack(spacing: 8) {
            periodSelector
            RecentStatCard(
                title: "TOTAL REQUESTS",
                value: service.recentStats.requestsDisplay,
                valueColor: .white.opacity(0.92)
            )
            RecentStatCard(
                title: "INPUT TOKENS",
                value: service.recentStats.inputTokensDisplay,
                valueColor: .orange.opacity(0.86)
            )
            RecentStatCard(
                title: "OUTPUT TOKENS",
                value: service.recentStats.outputTokensDisplay,
                valueColor: .green.opacity(0.82)
            )
            RecentStatCard(
                title: "EST. COST",
                value: service.recentStats.costDisplay,
                valueColor: .yellow.opacity(0.88),
                footnote: "Estimated, not actual billing"
            )
            Spacer(minLength: 0)
        }
    }

    private var periodSelector: some View {
        HStack(spacing: 2) {
            ForEach(RecentStatsPeriod.allCases) { period in
                Button {
                    Task { await service.setRecentStatsPeriod(period) }
                } label: {
                    Text(period.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(service.recentStatsPeriod == period ? .white.opacity(0.88) : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            service.recentStatsPeriod == period ? Color.purple.opacity(0.34) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
    }

    private var recentListColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Model")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("In / Out")
                    .frame(width: 108, alignment: .trailing)
                Text("When")
                    .frame(width: 52, alignment: .trailing)
            }
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(.white.opacity(0.38))
            .padding(.horizontal, 4)
            .padding(.vertical, 7)

            if service.isLoadingRecentRequests && service.recentRequests.isEmpty {
                VStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(.white.opacity(0.35))
                    Text("Loading recent requests...")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.38))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            } else if let error = service.recentRequestsError, service.recentRequests.isEmpty {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
            } else if service.recentRequests.isEmpty {
                Text("No recent requests")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.26))
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(service.recentRequests.enumerated()), id: \.element.id) { index, request in
                                let previous = index > 0 ? service.recentRequests[index - 1] : nil
                                RecentRequestRow(
                                    request: request,
                                    now: context.date,
                                    repeatsModel: previous?.model == request.model
                                )
                            }
                        }
                        .padding(.bottom, 120)
                    }
                    .frame(minHeight: 240, maxHeight: 520)
                }
            }
        }
    }

}

struct RecentUsageChartView: View {
    let points: [RecentUsageChartPoint]

    private var hasData: Bool {
        points.contains { $0.tokens > 0 }
    }

    private let lineColor = Color.indigo.opacity(0.9)

    private func compactTokens(_ value: Double) -> String {
        if value >= 1_000_000 {
            let m = value / 1_000_000
            return m == m.rounded() ? String(format: "%.0fM", m) : String(format: "%.1fM", m)
        }
        if value >= 1_000 {
            let k = value / 1_000
            return k == k.rounded() ? String(format: "%.0fK", k) : String(format: "%.1fK", k)
        }
        return String(format: "%.0f", value)
    }

    private var xAxisIndices: [Int] {
        guard !points.isEmpty else { return [] }
        // Hourly data ("HH:MM"): mark every 3rd hour (0h, 3h, 6h, ...).
        let hourly = points.enumerated().compactMap { index, point -> Int? in
            let parts = point.label.split(separator: ":")
            guard parts.count == 2, let hour = Int(parts[0]) else { return nil }
            return hour % 3 == 0 ? index : nil
        }
        if !hourly.isEmpty { return hourly }
        // Fallback for non-hourly (date) labels.
        guard points.count > 2 else { return [0] }
        let last = points.count - 1
        return [0, Int(Double(last) * 0.25), Int(Double(last) * 0.5), Int(Double(last) * 0.75), last]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOKENS USED")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.42))

            if hasData {
                Chart {
                    ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                        AreaMark(
                            x: .value("Time", index),
                            y: .value("Tokens", point.tokens)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [lineColor.opacity(0.32), lineColor.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Time", index),
                            y: .value("Tokens", point.tokens)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(lineColor)
                        .lineStyle(StrokeStyle(lineWidth: 1.6))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: xAxisIndices) { value in
                        AxisGridLine()
                            .foregroundStyle(.white.opacity(0.06))
                        if let index = value.as(Int.self), index < points.count {
                            AxisValueLabel {
                                Text(points[index].label)
                                    .font(.system(size: 7))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                            .foregroundStyle(.white.opacity(0.06))
                        AxisValueLabel {
                            if let tokens = value.as(Double.self) {
                                Text(compactTokens(tokens))
                                    .font(.system(size: 7))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                    }
                }
                .frame(height: 150)
            } else {
                Text("No data for this period")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct RecentStatCard: View {
    let title: String
    let value: String
    let valueColor: Color
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.42))
            Text(value)
                .font(.system(size: 19, weight: .bold).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let footnote {
                Text(footnote)
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct QuotaAccountSkeletonRow: View {
    let index: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 6, height: 6)
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: index.isMultiple(of: 2) ? 138 : 188, height: 9)
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 30, height: 16)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider().background(Color.white.opacity(0.04))

            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 96, height: 8)
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 300, height: 4)
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 58, height: 8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        )
    }
}

struct RecentRequestRow: View {
    let request: RecentRequest
    let now: Date
    var repeatsModel: Bool = false

    private var promptTokensText: String {
        formatTokenCount(request.promptTokens)
    }

    private var completionTokensText: String {
        formatTokenCount(request.completionTokens)
    }

    private var providerText: String {
        let parts = request.provider.split(separator: "-", maxSplits: 2).map(String.init)
        guard parts.count >= 3,
              UUID(uuidString: parts[2]) != nil else {
            return request.provider
        }
        return "\(parts[0])-\(parts[1])-\(parts[2].prefix(8))…"
    }

    private func formatTokenCount(_ value: Int) -> String {
        RecentRequestRow.tokenFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let tokenFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private var statusColor: Color {
        switch request.status.lowercased() {
        case "success", "ok", "completed": return .green
        case "error", "failed", "failure": return .red
        default: return .orange
        }
    }

    private var relativeTime: String {
        guard let date = requestDate else { return "—" }
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }

    private var requestDate: Date? {
        request.timestampDate
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(request.model)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(repeatsModel ? 0.4 : 0.86))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(providerText)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Text("\(promptTokensText)↑")
                    .foregroundStyle(.orange.opacity(0.82))
                Text("\(completionTokensText)↓")
                    .foregroundStyle(.green.opacity(0.82))
            }
            .font(.system(size: 10.5).monospacedDigit())
            .frame(width: 108, alignment: .trailing)

            Text(relativeTime)
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
        }
    }
}
