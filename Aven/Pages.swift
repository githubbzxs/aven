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

private struct IncomeSource: Identifiable {
    let name: String
    let cadence: String
    let symbol: String
    let earnings: Double
    let share: String

    var id: String { name }
}

private enum EarningsMockData {
    static let totalEarnings = 42_680.24
    static let referenceDate = Calendar.current.startOfDay(for: .now)

    static let sources = [
        IncomeSource(
            name: "Quant Bot",
            cadence: "Always on",
            symbol: "waveform.path.ecg",
            earnings: 18_460.80,
            share: "43.3%"
        ),
        IncomeSource(
            name: "Studio Retainers",
            cadence: "Monthly",
            symbol: "person.2.fill",
            earnings: 9_840.00,
            share: "23.1%"
        ),
        IncomeSource(
            name: "Micro SaaS",
            cadence: "Recurring",
            symbol: "server.rack",
            earnings: 8_220.50,
            share: "19.3%"
        ),
        IncomeSource(
            name: "Digital Products",
            cadence: "One-time",
            symbol: "shippingbox.fill",
            earnings: 6_158.94,
            share: "14.4%"
        )
    ]

    static func earnings(for range: EarningsRange) -> [EarningsPoint] {
        let values: [Double] = switch range {
        case .week:
            [38_920, 39_040, 39_040, 39_780, 39_780, 40_110, 40_110,
             41_620, 41_620, 42_080, 42_080, totalEarnings]
        case .month:
            [31_220, 31_220, 31_940, 31_940, 33_260, 33_260, 33_420,
             34_880, 34_880, 36_020, 36_020, 36_940, 36_940, 38_640,
             38_640, 39_010, 39_010, 40_980, 40_980, 41_360, 41_360,
             totalEarnings]
        case .quarter:
            [20_100, 21_800, 21_800, 24_400, 24_400, 24_900, 26_800,
             26_800, 29_600, 29_600, 32_500, 32_500, 34_200, 35_900,
             35_900, 38_700, 38_700, 40_800, 40_800, totalEarnings]
        case .year:
            [2_400, 2_400, 4_980, 4_980, 7_600, 9_800, 9_800, 13_200,
             13_200, 16_800, 19_600, 19_600, 23_900, 23_900, 27_600,
             31_200, 31_200, 34_900, 34_900, 38_800, 40_100, 40_100,
             totalEarnings]
        }

        let interval = TimeInterval(range.daySpan * 24 * 60 * 60)

        return values.enumerated().map { index, value in
            let progress = Double(index) / Double(values.count - 1)
            let date = referenceDate.addingTimeInterval(-interval * (1 - progress))
            return EarningsPoint(date: date, value: value)
        }
    }
}

struct DashboardView: View {
    @State private var selectedRange: EarningsRange = .month
    @State private var selectedPoint: EarningsPoint?
    @State private var revealProgress = 0.0

    private var earningsPoints: [EarningsPoint] {
        EarningsMockData.earnings(for: selectedRange)
    }

    private var displayedEarnings: Double {
        selectedPoint?.value ?? EarningsMockData.totalEarnings
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
        let spread = Swift.max(upperValue - lowerValue, 1)
        let lowerBound = Swift.max(0, lowerValue - spread * 0.12)

        return lowerBound...(upperValue + spread * 0.10)
    }

    private var highlightedProgress: Double {
        guard
            let selectedPoint,
            let firstDate = earningsPoints.first?.date,
            let lastDate = earningsPoints.last?.date
        else {
            return revealProgress
        }

        let fullInterval = lastDate.timeIntervalSince(firstDate)
        guard fullInterval > 0 else { return 1 }

        return min(max(selectedPoint.date.timeIntervalSince(firstDate) / fullInterval, 0), 1)
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    earningsHeader
                    earningsChart
                    dateLabels
                    rangeSelector
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .task(id: selectedRange) {
            selectedPoint = nil
            revealProgress = 0

            try? await Task.sleep(for: .milliseconds(70))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 1.05)) {
                revealProgress = 1
            }
        }
        .accessibilityIdentifier("screen.dashboard")
    }

    private var earningsHeader: some View {
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

            Text(displayedEarnings.usdText)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .tracking(-1.25)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText(value: displayedEarnings))
                .animation(.snappy(duration: 0.18), value: displayedEarnings)
                .padding(.top, 8)

            Group {
                if let selectedPoint {
                    Text(selectedPoint.date.selectedDateText)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 7) {
                        Text(periodGain.signedUSDText)
                            .foregroundStyle(Color.accentColor)

                        Text("\(periodChange.percentText) · \(selectedRange.rawValue)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .padding(.top, 7)
        }
    }

    private var earningsChart: some View {
        ZStack {
            EarningsCurveLayer(
                points: earningsPoints,
                chartDomain: chartDomain,
                lineWidth: 2,
                lineOpacity: selectedPoint == nil ? 0 : 0.14,
                areaTopOpacity: 0
            )

            ZStack {
                EarningsCurveLayer(
                    points: earningsPoints,
                    chartDomain: chartDomain,
                    lineWidth: 9,
                    lineOpacity: 0.20,
                    areaTopOpacity: 0
                )
                .blur(radius: 7)

                EarningsCurveLayer(
                    points: earningsPoints,
                    chartDomain: chartDomain,
                    lineWidth: 2.6,
                    lineOpacity: 1,
                    areaTopOpacity: 0.22
                )
            }
            .mask(alignment: .leading) {
                GeometryReader { geometry in
                    Rectangle()
                        .frame(width: geometry.size.width * highlightedProgress)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            EarningsCurveInteractionLayer(
                points: earningsPoints,
                chartDomain: chartDomain,
                selectedPoint: $selectedPoint
            )
        }
        .frame(height: 252)
        .padding(.top, 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total earnings across all sources")
        .accessibilityValue(displayedEarnings.usdText)
    }

    private var dateLabels: some View {
        HStack {
            Text(earningsPoints.first?.date.shortDateText ?? "")

            Spacer()

            Text(earningsPoints.middlePoint?.date.shortDateText ?? "")

            Spacer()

            Text(earningsPoints.last?.date.shortDateText ?? "")
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.top, 5)
    }

    private var rangeSelector: some View {
        HStack(spacing: 8) {
            ForEach(EarningsRange.allCases) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedRange == range ? Color.accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            selectedRange == range ? Color.accentColor.opacity(0.14) : .clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show \(range.rawValue) earnings")
            }
        }
        .padding(.top, 17)
    }
}

private struct EarningsCurveLayer: View {
    let points: [EarningsPoint]
    let chartDomain: ClosedRange<Double>
    let lineWidth: CGFloat
    let lineOpacity: Double
    let areaTopOpacity: Double

    var body: some View {
        Chart(points) { point in
            if areaTopOpacity > 0 {
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Baseline", chartDomain.lowerBound),
                    yEnd: .value("Earnings", point.value)
                )
                .interpolationMethod(.stepEnd)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(areaTopOpacity),
                            Color.accentColor.opacity(0.045),
                            Color.accentColor.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            LineMark(
                x: .value("Date", point.date),
                y: .value("Earnings", point.value)
            )
            .interpolationMethod(.stepEnd)
            .lineStyle(
                StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .foregroundStyle(Color.accentColor.opacity(lineOpacity))
        }
        .chartXScale(domain: chartDateDomain)
        .chartYScale(domain: chartDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.background(.clear)
        }
        .allowsHitTesting(false)
    }

    private var chartDateDomain: ClosedRange<Date> {
        let start = points.first?.date ?? .now
        let end = points.last?.date ?? start.addingTimeInterval(1)
        return start...end
    }
}

private struct EarningsCurveInteractionLayer: View {
    let points: [EarningsPoint]
    let chartDomain: ClosedRange<Double>
    @Binding var selectedPoint: EarningsPoint?

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Earnings", point.value)
            )
            .foregroundStyle(.clear)
        }
        .chartXScale(domain: chartDateDomain)
        .chartYScale(domain: chartDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.background(.clear)
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    let plotRect = geometry[plotFrame]

                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { gesture in
                                        updateSelection(
                                            at: gesture.location.x - plotRect.minX,
                                            plotWidth: plotRect.width,
                                            proxy: proxy
                                        )
                                    }
                                    .onEnded { _ in
                                        withAnimation(.easeOut(duration: 0.24)) {
                                            selectedPoint = nil
                                        }
                                    }
                            )

                        if
                            let selectedPoint,
                            let pointX = proxy.position(forX: selectedPoint.date),
                            let pointY = proxy.position(forY: selectedPoint.value)
                        {
                            selectionIndicator(
                                pointX: plotRect.minX + pointX,
                                pointY: plotRect.minY + pointY,
                                plotRect: plotRect,
                                date: selectedPoint.date
                            )
                        }
                    }
                }
            }
        }
    }

    private var chartDateDomain: ClosedRange<Date> {
        let start = points.first?.date ?? .now
        let end = points.last?.date ?? start.addingTimeInterval(1)
        return start...end
    }

    private func updateSelection(at xPosition: CGFloat, plotWidth: CGFloat, proxy: ChartProxy) {
        let clampedX = min(max(xPosition, 0), plotWidth)
        guard let date: Date = proxy.value(atX: clampedX) else { return }

        selectedPoint = points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }

    @ViewBuilder
    private func selectionIndicator(
        pointX: CGFloat,
        pointY: CGFloat,
        plotRect: CGRect,
        date: Date
    ) -> some View {
        let labelX = min(max(pointX, plotRect.minX + 30), plotRect.maxX - 30)
        let guideTop = plotRect.minY + 24
        let guideBottom = max(guideTop, pointY - 8)

        Path { path in
            path.move(to: CGPoint(x: pointX, y: guideTop))
            path.addLine(to: CGPoint(x: pointX, y: guideBottom))
        }
        .stroke(Color.white.opacity(0.22), lineWidth: 0.8)

        Text(date.shortDateText)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .position(x: labelX, y: plotRect.minY + 8)

        Circle()
            .fill(Color.accentColor.opacity(0.24))
            .frame(width: 20, height: 20)
            .blur(radius: 4)
            .position(x: pointX, y: pointY)

        Circle()
            .fill(.white)
            .frame(width: 6, height: 6)
            .overlay {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
            }
            .position(x: pointX, y: pointY)
    }
}

struct SourcesView: View {
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Sources")
                        .font(.largeTitle.weight(.semibold))

                    Text("\(EarningsMockData.sources.count) income streams")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 5)

                    HStack(alignment: .firstTextBaseline) {
                        Text("Total earnings")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(EarningsMockData.totalEarnings.usdText)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 18)

                    Divider()
                        .overlay(Color.white.opacity(0.08))

                    ForEach(Array(EarningsMockData.sources.enumerated()), id: \.element.id) { index, source in
                        sourceRow(source)

                        if index < EarningsMockData.sources.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.07))
                                .padding(.leading, 50)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier("screen.sources")
    }

    private func sourceRow(_ source: IncomeSource) -> some View {
        HStack(spacing: 14) {
            Image(systemName: source.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(.body.weight(.medium))

                Text(source.cadence)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(source.earnings.usdText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()

                Text(source.share)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }
}

struct SettingsView: View {
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(.largeTitle.weight(.semibold))

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 30)
            .padding(.bottom, 120)
        }
        .accessibilityIdentifier("screen.settings")
    }
}

private extension Array where Element == EarningsPoint {
    var middlePoint: EarningsPoint? {
        guard !isEmpty else { return nil }
        return self[count / 2]
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

    var selectedDateText: String {
        formatted(.dateTime.month(.wide).day().year())
    }
}
