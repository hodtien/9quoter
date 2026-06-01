import SwiftUI

struct AccountQuotaCard: View {
    let account: ProviderQuota
    let baseURL: String
    let onRefresh: () -> Void
    let onToggle: (Bool) -> Void
    @State private var isToggling = false

    private var visibleQuotas: [(key: String, value: QuotaEntry)] {
        account.quotas.filter { !$0.value.unlimited }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(account.isActive ? Color.green.opacity(0.72) : Color.white.opacity(0.24))
                        .frame(width: 6, height: 6)
                    Text(account.displayName)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(account.isActive ? 0.84 : 0.46))
                        .lineLimit(1)
                    if account.isLoadingQuota {
                        Text("checking")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(Color.purple.opacity(0.82))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.10), in: Capsule())
                            .lineLimit(1)
                    } else if !account.plan.isEmpty && account.plan != "unknown" {
                        Text(account.plan)
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.34))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.055), in: Capsule())
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(account.isLoadingQuota ? 0.18 : 0.34))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(account.isLoadingQuota)
                .help("Refresh this account")

                Button {
                    isToggling = true
                    onToggle(!account.isActive)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        isToggling = false
                    }
                } label: {
                    ZStack(alignment: account.isActive ? .trailing : .leading) {
                        Capsule()
                            .fill(account.isActive ? Color.purple.opacity(0.72) : Color.white.opacity(0.10))
                            .frame(width: 30, height: 16)

                        if isToggling {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white.opacity(0.85))
                                .frame(width: 14, height: 14)
                                .padding(.horizontal, 1)
                        } else {
                            Circle()
                                .fill(account.isActive ? Color.white : Color.white.opacity(0.65))
                                .frame(width: 12, height: 12)
                                .padding(.horizontal, 2)
                        }
                    }
                    .animation(.easeInOut(duration: 0.16), value: account.isActive)
                }
                .buttonStyle(.plain)
                .help(account.isActive ? "Disable account" : "Enable account")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)

            if account.isLoadingQuota {
                Divider().background(Color.white.opacity(0.05))
                QuotaLoadingRows()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
            } else if visibleQuotas.isEmpty {
                Divider().background(Color.white.opacity(0.05))
                Text(emptyText)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.32))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                Divider().background(Color.white.opacity(0.05))
                VStack(spacing: 0) {
                    ForEach(visibleQuotas, id: \.key) { item in
                        CompactQuotaRow(label: item.key, entry: item.value)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .background(Color.white.opacity(account.isActive ? 0.047 : 0.05), in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.white.opacity(account.isActive ? 0.055 : 0.05), lineWidth: 1)
        )
    }

    private var emptyText: String {
        if let message = account.message, !message.isEmpty {
            return message
        }
        if account.quotaUnavailable {
            return "Quota unavailable"
        }
        if account.provider.hasPrefix("claude") {
            return "Claude connected. Usage API requires admin permissions."
        }
        return "No quota data"
    }
}

struct QuotaLoadingRows: View {
    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                Capsule()
                    .fill(Color.purple.opacity(0.55))
                    .frame(width: 6, height: 6)
                Text("Checking quota")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.44))
                Spacer()
            }

            HStack(spacing: 8) {
                ShimmerBar(width: 150, height: 7)
                ShimmerBar(width: 268, height: 4)
                ShimmerBar(width: 92, height: 7)
            }
        }
    }
}

struct ShimmerBar: View {
    let width: CGFloat
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.09))
            .frame(width: width, height: height)
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.0),
                                        .white.opacity(0.26),
                                        .white.opacity(0.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * 0.46, height: geo.size.height)
                            .offset(x: isAnimating ? geo.size.width : -geo.size.width * 0.5)
                    }
                    .clipShape(Capsule())
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                isAnimating = true
            }
            .onDisappear {
                isAnimating = false
            }
            .animation(
                reduceMotion ? nil : .linear(duration: 1.15).repeatForever(autoreverses: false),
                value: isAnimating
            )
    }
}

struct CompactQuotaRow: View {
    let label: String
    let entry: QuotaEntry

    private var remainingPct: Int {
        guard !entry.unlimited, entry.total > 0 else { return 100 }
        if let pct = entry.remainingPercentage { return Int(pct) }
        return Int(entry.remaining / entry.total * 100)
    }

    private var remainingFraction: Double {
        guard !entry.unlimited, entry.total > 0 else { return 1 }
        if let pct = entry.remainingPercentage { return pct / 100.0 }
        return entry.remaining / entry.total
    }

    private var color: Color {
        if remainingPct <= 10 { return .red }
        if remainingPct <= 35 { return .yellow }
        return .green
    }

    private var resetText: String {
        guard let str = entry.resetAt,
              let date = resetDate(from: str) else { return "—" }
        let diff = max(0, date.timeIntervalSince(Date()))
        let h = Int(diff / 3600)
        let m = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
        if h >= 24 { return "in \(h / 24)d \(h % 24)h" }
        if h > 0 { return "in \(h)h \(m)m" }
        return "in \(m)m"
    }

    private func resetDate(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
                    .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .stroke(color.opacity(0.35), lineWidth: 1)
                        Capsule()
                            .fill(color.opacity(0.9))
                            .frame(width: geo.size.width * min(remainingFraction, 1))
                    }
                }
                .frame(height: 4)

                HStack(spacing: 0) {
                    Text(entry.unlimited ? "0 / ∞" : "\(entry.usedDisplay) / \(entry.totalDisplay)")
                        .font(.system(size: 8.5).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.34))

                    Spacer()

                    Text(entry.unlimited ? "∞" : "\(remainingPct)%")
                        .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(color.opacity(0.92))
                }
            }
            .frame(width: 268, alignment: .leading)
            Text(resetText)
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(resetText == "—" ? 0.22 : 0.52))
                .lineLimit(1)
                .frame(width: 92, alignment: .leading)
        }
    }
}
