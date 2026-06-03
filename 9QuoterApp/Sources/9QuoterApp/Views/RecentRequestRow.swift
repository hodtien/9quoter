import SwiftUI

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
