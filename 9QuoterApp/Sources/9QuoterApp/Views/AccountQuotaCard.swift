import SwiftUI

struct AccountQuotaCard: View {
    let account: ProviderQuota
    let baseURL: String
    let onToggle: (Bool) -> Void
    @State private var isToggling = false

    private var visibleQuotas: [(key: String, value: QuotaEntry)] {
        account.quotas.filter { !$0.value.unlimited }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(account.displayName)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(1)
                    if !account.plan.isEmpty && account.plan != "unknown" {
                        Text(account.plan)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.32))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    isToggling = true
                    onToggle(!account.isActive)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        isToggling = false
                    }
                } label: {
                    ZStack(alignment: account.isActive ? .trailing : .leading) {
                        Capsule()
                            .fill(account.isActive ? Color(red: 0.92, green: 0.36, blue: 0.25) : Color.white.opacity(0.10))
                            .frame(width: 32, height: 18)

                        if isToggling {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white.opacity(0.85))
                                .frame(width: 16, height: 16)
                                .padding(.horizontal, 1)
                        } else {
                            Circle()
                                .fill(account.isActive ? Color.white : Color.white.opacity(0.65))
                                .frame(width: 14, height: 14)
                                .padding(.horizontal, 2)
                        }
                    }
                    .animation(.easeInOut(duration: 0.16), value: account.isActive)
                }
                .buttonStyle(.plain)
                .help(account.isActive ? "Disable account" : "Enable account")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)

            if visibleQuotas.isEmpty {
                Divider().background(Color.white.opacity(0.05))
                Text(emptyText)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.32))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            } else {
                Divider().background(Color.white.opacity(0.05))
                VStack(spacing: 0) {
                    ForEach(visibleQuotas, id: \.key) { item in
                        CompactQuotaRow(label: item.key, entry: item.value)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .background(Color.white.opacity(0.047), in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        )
    }

    private var emptyText: String {
        if account.provider.hasPrefix("claude") {
            return "Claude connected. Usage API requires admin permissions."
        }
        return "No quota data"
    }
}

struct CompactQuotaRow: View {
    let label: String
    let entry: QuotaEntry

    private var remainingPct: Int {
        guard !entry.unlimited, entry.total > 0 else { return 100 }
        if let pct = entry.remainingPercentage { return Int(pct) }
        return Int(Double(entry.remaining) / Double(entry.total) * 100)
    }

    private var remainingFraction: Double {
        guard !entry.unlimited, entry.total > 0 else { return 1 }
        return Double(entry.remaining) / Double(entry.total)
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
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(1)
            }
            .frame(width: 118, alignment: .leading)

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
                    Text(entry.unlimited ? "0 / ∞" : "\(entry.used) / \(entry.total)")
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.36))

                    Spacer()

                    Text(entry.unlimited ? "∞" : "\(remainingPct)%")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(color)
                }
            }
            .frame(width: 300, alignment: .leading)

            Text(resetText)
                .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(resetText == "—" ? 0.22 : 0.58))
                .lineLimit(1)
                .frame(width: 92, alignment: .leading)
        }
    }
}
