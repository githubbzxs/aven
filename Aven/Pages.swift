import Charts
import SwiftUI

private enum EarningsRange: String, CaseIterable, Identifiable {
    case day = "1D"
    case week = "7D"
    case month = "30D"
    case year = "1Y"

    var id: Self { self }

    var daySpan: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 30
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
    static let referenceDate = Date.now

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
        let anchors: [Double] = switch range {
        case .day:
            [42_040, 42_080, 42_210, 42_170, 42_360, 42_610, 42_540,
             42_820, 43_070, 43_260, 43_190, 42_980, 42_690, 42_430,
             42_370, 42_540, 42_760, 42_890, 42_830, 42_940, 42_860,
             42_790, totalEarnings]
        case .week:
            [39_180, 39_260, 39_840, 40_620, 40_310, 41_180, 42_460,
             42_070, 43_240, 44_610, 45_180, 44_820, 43_960, 42_520,
             41_610, 41_280, 41_940, 42_880, 43_620, 43_410, 43_020,
             totalEarnings]
        case .month:
            [31_820, 31_960, 32_740, 33_980, 33_620, 35_140, 36_920,
             36_410, 38_760, 40_940, 40_280, 42_860, 44_720, 44_190,
             45_680, 47_120, 46_740, 45_560, 43_620, 41_480, 40_720,
             41_260, 42_780, 44_060, 43_740, 43_210, totalEarnings]
        case .year:
            [7_600, 8_180, 10_920, 14_600, 13_240, 17_880, 22_760,
             21_040, 26_880, 31_420, 29_760, 35_940, 41_680, 39_820,
             44_960, 49_840, 52_360, 50_920, 46_180, 40_640, 35_280,
             33_920, 37_460, 42_780, 46_120, 45_480, 44_260, totalEarnings]
        }
        let values = densifiedValues(from: anchors)

        let interval = TimeInterval(range.daySpan * 24 * 60 * 60)

        return values.enumerated().map { index, value in
            let progress = Double(index) / Double(values.count - 1)
            let date = referenceDate.addingTimeInterval(-interval * (1 - progress))
            return EarningsPoint(date: date, value: value)
        }
    }

    private static func densifiedValues(from anchors: [Double]) -> [Double] {
        guard anchors.count > 1 else { return anchors }

        let samplesPerSegment = 3
        var values: [Double] = []
        values.reserveCapacity((anchors.count - 1) * samplesPerSegment + 1)

        for index in anchors.indices.dropLast() {
            let start = anchors[index]
            let end = anchors[index + 1]

            for step in 0..<samplesPerSegment {
                let progress = Double(step) / Double(samplesPerSegment)
                values.append(start + (end - start) * progress)
            }
        }

        values.append(anchors[anchors.count - 1])
        return values
    }
}

struct DashboardView: View {
    @State private var selectedRange: EarningsRange = .month
    @State private var selectedPoint: EarningsPoint?
    @State private var displayedPoint: EarningsPoint?
    @State private var revealProgress = 0.0

    private var earningsPoints: [EarningsPoint] {
        EarningsMockData.earnings(for: selectedRange)
    }

    private var displayedEarnings: Double {
        displayedPoint?.value ?? EarningsMockData.totalEarnings
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

    private var dateLabelPoints: [EarningsPoint] {
        guard !earningsPoints.isEmpty else { return [] }

        let lastIndex = earningsPoints.count - 1
        return [0.0, 0.25, 0.5, 0.75, 1.0].map { progress in
            earningsPoints[Int((Double(lastIndex) * progress).rounded())]
        }
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
            displayedPoint = nil
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
            Text(displayedEarnings.usdText)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .tracking(-1.25)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText(value: displayedEarnings))
                .animation(.easeOut(duration: 0.30), value: displayedEarnings)

            HStack(spacing: 7) {
                Text(periodGain.signedUSDText)
                    .foregroundStyle(Color.accentColor)

                Text("\(periodChange.percentText) · \(selectedRange.rawValue)")
                    .foregroundStyle(.secondary)
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
                lineWidth: 2.2,
                lineOpacity: selectedPoint == nil ? 0 : 0.10,
                areaTopOpacity: 0
            )

            ZStack {
                EarningsCurveLayer(
                    points: earningsPoints,
                    chartDomain: chartDomain,
                    lineWidth: 10,
                    lineOpacity: 0.26,
                    areaTopOpacity: 0
                )
                .blur(radius: 8)

                EarningsCurveLayer(
                    points: earningsPoints,
                    chartDomain: chartDomain,
                    lineWidth: 2.4,
                    lineOpacity: 1,
                    areaTopOpacity: 0.09
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
                range: selectedRange,
                selectedPoint: $selectedPoint,
                displayedPoint: $displayedPoint
            )
        }
        .frame(height: 252)
        .padding(.top, 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total earnings across all sources")
        .accessibilityValue(displayedEarnings.usdText)
    }

    private var dateLabels: some View {
        HStack(spacing: 0) {
            ForEach(Array(dateLabelPoints.enumerated()), id: \.element.id) { index, point in
                Text(point.date.axisText(for: selectedRange))
                    .frame(
                        maxWidth: .infinity,
                        alignment: index == 0 ? .leading : index == dateLabelPoints.count - 1 ? .trailing : .center
                    )
            }
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
                        .foregroundStyle(selectedRange == range ? Color.primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            selectedRange == range ? Color.white.opacity(0.09) : .clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
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
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(areaTopOpacity),
                            Color.accentColor.opacity(areaTopOpacity * 0.22),
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
            .interpolationMethod(.catmullRom)
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
    let range: EarningsRange
    @Binding var selectedPoint: EarningsPoint?
    @Binding var displayedPoint: EarningsPoint?
    @State private var hapticStep = 0
    @State private var lastHapticCell: Int?
    @State private var lastDisplayedCell: Int?

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
                                        lastHapticCell = nil
                                        lastDisplayedCell = nil

                                        withAnimation(.easeOut(duration: 0.24)) {
                                            selectedPoint = nil
                                            displayedPoint = nil
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
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: hapticStep)
    }

    private var chartDateDomain: ClosedRange<Date> {
        let start = points.first?.date ?? .now
        let end = points.last?.date ?? start.addingTimeInterval(1)
        return start...end
    }

    private func updateSelection(at xPosition: CGFloat, plotWidth: CGFloat, proxy: ChartProxy) {
        let clampedX = min(max(xPosition, 0), plotWidth)
        let hapticCell = Int(clampedX / 5)

        if hapticCell != lastHapticCell {
            lastHapticCell = hapticCell
            hapticStep += 1
        }

        guard let date: Date = proxy.value(atX: clampedX) else { return }

        guard let nextPoint = points.min(by: { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }) else { return }

        let displayedCell = Int(clampedX / 20)
        if displayedCell != lastDisplayedCell {
            lastDisplayedCell = displayedCell
            displayedPoint = nextPoint
        }

        guard nextPoint.id != selectedPoint?.id else { return }

        selectedPoint = nextPoint
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
        .stroke(
            Color.white.opacity(0.28),
            style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [2, 3])
        )

        Text(date.crosshairText(for: range))
            .font(.caption2.weight(.semibold))
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
            .shadow(color: Color.accentColor.opacity(0.9), radius: 3)
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

    func axisText(for range: EarningsRange) -> String {
        switch range {
        case .day:
            formatted(.dateTime.hour().minute())
        case .week, .month, .year:
            shortDateText
        }
    }

    func crosshairText(for range: EarningsRange) -> String {
        switch range {
        case .day:
            formatted(.dateTime.hour().minute())
        case .week, .month, .year:
            shortDateText
        }
    }
}
