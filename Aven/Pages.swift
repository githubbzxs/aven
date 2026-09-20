import Charts
import SwiftUI

private enum EarningsRange: String, CaseIterable, Identifiable {
    case week = "7D"
    case month = "30D"
    case quarter = "90D"
    case year = "1Y"

    var id: Self { self }

    var daySpan: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .year: 365
        }
    }
}

private struct EarningsPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

private struct EarningsProject: Identifiable {
    let name: String
    let type: String
    let symbol: String
    let earnings: Double
    let share: String

    var id: String { name }
}

private enum DashboardMockData {
    static let totalEarnings = 42_680.24
    static let todayEarnings = 412.80
    static let monthEarnings = 6_940.12
    static let referenceDate = Calendar.current.startOfDay(for: .now)

    static let projects = [
        EarningsProject(
            name: "Quant Bot",
            type: "Long-term",
            symbol: "waveform.path.ecg",
            earnings: 18_460.80,
            share: "43.3%"
        ),
        EarningsProject(
            name: "Studio Retainers",
            type: "Recurring",
            symbol: "person.2.fill",
            earnings: 9_840.00,
            share: "23.1%"
        ),
        EarningsProject(
            name: "Micro SaaS",
            type: "Recurring",
            symbol: "server.rack",
            earnings: 8_220.50,
            share: "19.3%"
        ),
        EarningsProject(
            name: "Digital Products",
            type: "One-time",
            symbol: "shippingbox.fill",
            earnings: 6_158.94,
            share: "14.4%"
        )
    ]

    static func earnings(for range: EarningsRange) -> [EarningsPoint] {
        let values: [Double] = switch range {
        case .week:
            [39_240, 39_680, 40_150, 40_420, 40_980, 41_350, 42_120, totalEarnings]
        case .month:
            [31_240, 31_980, 32_450, 33_620, 34_080, 34_950, 35_780, 36_340,
             37_060, 37_820, 38_440, 39_310, 40_120, 40_860, 41_740, totalEarnings]
        case .quarter:
            [19_800, 21_050, 22_140, 23_980, 25_220, 26_540, 28_410, 29_760,
             31_080, 33_120, 34_680, 36_250, 37_940, 39_580, 41_020, totalEarnings]
        case .year:
            [1_600, 3_420, 5_980, 8_760, 11_240, 14_680, 17_950, 20_820,
             23_780, 27_160, 30_940, 34_120, 36_780, 39_220, 41_040, totalEarnings]
        }

        return values.enumerated().compactMap { index, value in
            let progress = Double(index) / Double(values.count - 1)
            let dayOffset = -range.daySpan + Int((Double(range.daySpan) * progress).rounded())

            guard let date = Calendar.current.date(
                byAdding: .day,
                value: dayOffset,
                to: referenceDate
            ) else {
                return nil
            }

            return EarningsPoint(date: date, value: value)
        }
    }
}

struct DashboardView: View {
    @State private var selectedRange: EarningsRange = .month

    private var earningsPoints: [EarningsPoint] {
        DashboardMockData.earnings(for: selectedRange)
    }

    private var periodGain: Double {
        guard let first = earningsPoints.first, let last = earningsPoints.last else {
            return 0
        }

        return last.value - first.value
    }

    private var periodChange: Double {
        guard let first = earningsPoints.first, first.value > 0 else {
            return 0
        }

        return periodGain / first.value * 100
    }

    private var chartDomain: ClosedRange<Double> {
        let values = earningsPoints.map(\.value)
        let lowerValue = values.min() ?? 0
        let upperValue = values.max() ?? 1
        let padding = Swift.max((upperValue - lowerValue) * 0.18, 500)

        return (lowerValue - padding)...(upperValue + padding * 0.12)
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    earningsOverview
                    quickStats

                    Divider()
                        .overlay(Color.white.opacity(0.08))
                        .padding(.vertical, 28)

                    projectsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier("screen.dashboard")
    }

    private var earningsOverview: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Total earnings")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("All sources")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }

            Text(DashboardMockData.totalEarnings.usdText)
                .font(.system(size: 39, weight: .semibold, design: .rounded))
                .tracking(-1.2)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .padding(.top, 8)

            HStack(spacing: 7) {
                Text(periodGain.signedUSDText)
                    .foregroundStyle(Color.accentColor)

                Text("\(periodChange.percentText) · \(selectedRange.rawValue)")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .padding(.top, 7)

            Chart(earningsPoints) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Baseline", chartDomain.lowerBound),
                    yEnd: .value("Earnings", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.28),
                            Color.accentColor.opacity(0.015)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Earnings", point.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Color.accentColor)

                if point.id == earningsPoints.last?.id {
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Earnings", point.value)
                    )
                    .symbolSize(34)
                    .foregroundStyle(Color.accentColor)
                }
            }
            .chartXScale(domain: (earningsPoints.first?.date ?? .now)...(earningsPoints.last?.date ?? .now))
            .chartYScale(domain: chartDomain)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { plotArea in
                plotArea.background(.clear)
            }
            .frame(height: 228)
            .padding(.top, 20)
            .animation(.easeInOut(duration: 0.28), value: selectedRange)
            .accessibilityLabel("Total earnings across all sources")
            .accessibilityValue(DashboardMockData.totalEarnings.usdText)

            HStack {
                Text(earningsPoints.first?.date.shortDateText ?? "")
                Spacer()
                Text(earningsPoints.last?.date.shortDateText ?? "")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.top, 4)

            HStack(spacing: 0) {
                ForEach(EarningsRange.allCases) { range in
                    Button {
                        selectedRange = range
                    } label: {
                        VStack(spacing: 7) {
                            Text(range.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedRange == range ? Color.accentColor : .secondary)

                            Capsule()
                                .fill(selectedRange == range ? Color.accentColor : .clear)
                                .frame(width: 18, height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show \(range.rawValue) earnings")
                }
            }
            .padding(.top, 17)
        }
    }

    private var quickStats: some View {
        HStack(alignment: .top, spacing: 16) {
            metric(title: "Today", value: DashboardMockData.todayEarnings.signedUSDText)
            metric(title: "This month", value: DashboardMockData.monthEarnings.signedUSDText)
            metric(title: "Active", value: "4 sources")
        }
        .padding(.top, 30)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Projects")
                    .font(.title3.weight(.semibold))

                Spacer()

                Text("Contribution")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ForEach(Array(DashboardMockData.projects.enumerated()), id: \.element.id) { index, project in
                HStack(spacing: 13) {
                    Image(systemName: project.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.body.weight(.medium))

                        Text(project.type)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(project.earnings.usdText)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()

                        Text(project.share)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(.vertical, 15)
                .accessibilityElement(children: .combine)

                if index < DashboardMockData.projects.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.07))
                        .padding(.leading, 49)
                }
            }
        }
    }
}

struct AgentView: View {
    var body: some View {
        AppTheme.background
            .ignoresSafeArea()
            .accessibilityIdentifier("screen.agent")
    }
}

struct SourcesView: View {
    var body: some View {
        AppTheme.background
            .ignoresSafeArea()
            .accessibilityIdentifier("screen.sources")
    }
}

private extension Double {
    var usdText: String {
        "$" + formatted(.number.precision(.fractionLength(2)))
    }

    var signedUSDText: String {
        let sign = self >= 0 ? "+" : "−"
        return sign + "$" + magnitude.formatted(.number.precision(.fractionLength(2)))
    }

    var percentText: String {
        formatted(.number.precision(.fractionLength(1))) + "%"
    }
}

private extension Date {
    var shortDateText: String {
        formatted(.dateTime.month(.abbreviated).day())
    }
}
