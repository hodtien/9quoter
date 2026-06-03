import SwiftUI
import Charts

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
