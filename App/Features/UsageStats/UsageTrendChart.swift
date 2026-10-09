import Charts
import NeodexKit
import SwiftUI

/// A Pokémon's usage over the most recent months of a format, as a Swift Charts line.
struct UsageTrendChart: View {
    var selection: UsageSelection
    var name: String

    @State private var points: [UsageTrendPoint] = []
    @State private var isLoading = true

    var body: some View {
        Section {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if points.count < 2 {
                Text("Smogon doesn't have enough months of this format to chart a trend yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                chart
                if let first = points.first, let last = points.last {
                    Text(trendText(from: first, to: last))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Usage Trend")
        }
        .task(id: selection) {
            isLoading = true
            points = await SmogonStatsClient.shared.usageTrend(for: name, format: selection.format, rating: selection.rating, months: 8)
            isLoading = false
        }
    }

    /// Pads the domain past the last month so its axis label isn't dropped at the plot's edge.
    private var xDomain: ClosedRange<Date> {
        let first = points.first?.date ?? .now
        let last = points.last?.date ?? .now
        return first.addingTimeInterval(-3 * 86_400)...last.addingTimeInterval(12 * 86_400)
    }

    private var chart: some View {
        let maximum = points.map(\.usagePercent).max() ?? 1
        return Chart(points) { point in
            AreaMark(x: .value("Month", point.date), y: .value("Usage", point.usagePercent))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.35), .blue.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Month", point.date), y: .value("Usage", point.usagePercent))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            PointMark(x: .value("Month", point.date), y: .value("Usage", point.usagePercent))
                .foregroundStyle(point.month == selection.month ? Color.orange : Color.blue)
                .symbolSize(point.month == selection.month ? 90 : 40)
                .annotation(position: .top, spacing: 4) {
                    if point.month == selection.month {
                        Text(point.usagePercent.formatted(.number.precision(.fractionLength(1))) + "%")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .chartYScale(domain: 0...(maximum * 1.25 + 0.5))
        .chartXScale(domain: xDomain, range: .plotDimension(startPadding: 12, endPadding: 12))
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number.formatted(.number.precision(.fractionLength(0))) + "%")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .frame(height: 180)
        .padding(.vertical, 4)
        .accessibilityLabel("\(name)'s usage over the last \(points.count) months")
    }

    private func trendText(from first: UsageTrendPoint, to last: UsageTrendPoint) -> String {
        let delta = last.usagePercent - first.usagePercent
        let since = UsageStatsModel.displayMonth(first.month)
        let change = delta.magnitude.formatted(.number.precision(.fractionLength(1)))
        let direction = delta > 0.05 ? "Up \(change) points" : delta < -0.05 ? "Down \(change) points" : "Steady"
        let rank = last.rank.map { " · #\($0) in \(UsageStatsModel.displayMonth(last.month))" } ?? ""
        return "\(direction) since \(since)\(rank)"
    }
}
