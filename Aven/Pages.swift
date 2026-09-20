import Charts
import SwiftUI

private enum EarningsRange: String, CaseIterable, Identifiable {
    case day = "24H"
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

    var minuteCount: Int {
        daySpan * 24 * 60
    }

    var chartBucketMinutes: Int {
        switch self {
        case .day: 2
        case .week: 15
        case .month: 60
        case .year: 12 * 60
        }
    }
}

private struct EarningsPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

private struct EarningsSeries {
    let minuteCount: Int
    let chartPoints: [EarningsPoint]
    let valueDomain: ClosedRange<Double>
    let firstPoint: EarningsPoint
    let lastPoint: EarningsPoint
}

private struct IncomeSource: Identifiable {
    let name: String
    let cadence: String
    let symbol: String
    let earnings: Double
    let share: String

    var id: String { name }
}

private struct SourceSignalProfile {
    let phase: Double
    let shortCycleMinutes: Double
    let rangeCycles: Double
    let amplitude: Double
}

private struct MonotoneTrend {
    let values: [Double]
    private let tangents: [Double]

    init(values: [Double]) {
        self.values = values

        guard values.count > 1 else {
            tangents = Array(repeating: 0, count: values.count)
            return
        }

        let secants = values.indices.dropLast().map { index in
            values[index + 1] - values[index]
        }
        var slopes = Array(repeating: 0.0, count: values.count)
        slopes[0] = secants[0]
        slopes[values.count - 1] = secants[secants.count - 1]

        if values.count > 2 {
            for index in 1..<(values.count - 1) {
                let previous = secants[index - 1]
                let next = secants[index]
                slopes[index] = previous * next <= 0 ? 0 : (previous + next) / 2
            }
        }

        for index in secants.indices {
            let secant = secants[index]
            guard secant != 0 else {
                slopes[index] = 0
                slopes[index + 1] = 0
                continue
            }

            let lowerRatio = slopes[index] / secant
            let upperRatio = slopes[index + 1] / secant
            let magnitude = lowerRatio * lowerRatio + upperRatio * upperRatio

            if magnitude > 9 {
                let scale = 3 / sqrt(magnitude)
                slopes[index] = scale * lowerRatio * secant
                slopes[index + 1] = scale * upperRatio * secant
            }
        }

        tangents = slopes
    }

    func value(at progress: Double) -> Double {
        guard values.count > 1 else { return values.first ?? 0 }

        let clampedProgress = min(max(progress, 0), 1)
        guard clampedProgress < 1 else { return values[values.count - 1] }

        let position = clampedProgress * Double(values.count - 1)
        let lowerIndex = min(Int(position), values.count - 2)
        let segmentProgress = position - Double(lowerIndex)
        let squaredProgress = segmentProgress * segmentProgress
        let cubedProgress = squaredProgress * segmentProgress

        let lowerWeight = 2 * cubedProgress - 3 * squaredProgress + 1
        let lowerTangentWeight = cubedProgress - 2 * squaredProgress + segmentProgress
        let upperWeight = -2 * cubedProgress + 3 * squaredProgress
        let upperTangentWeight = cubedProgress - squaredProgress

        return lowerWeight * values[lowerIndex]
            + lowerTangentWeight * tangents[lowerIndex]
            + upperWeight * values[lowerIndex + 1]
            + upperTangentWeight * tangents[lowerIndex + 1]
    }
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

    private static let sourceProfiles = [
        SourceSignalProfile(phase: 0.4, shortCycleMinutes: 240, rangeCycles: 1.4, amplitude: 0.0012),
        SourceSignalProfile(phase: 1.7, shortCycleMinutes: 360, rangeCycles: 0.9, amplitude: 0.0007),
        SourceSignalProfile(phase: 2.8, shortCycleMinutes: 300, rangeCycles: 1.8, amplitude: 0.0010),
        SourceSignalProfile(phase: 4.2, shortCycleMinutes: 480, rangeCycles: 1.2, amplitude: 0.0009)
    ]

    private static let dayAnchors = [
        42_420.0, 42_300, 42_080, 41_940, 42_020, 42_180, 42_430,
        42_710, 42_930, 42_850, 42_760, 42_820, 42_980, 43_160,
        43_340, 43_420, 43_390, 43_220, 43_000, 42_880, 42_810,
        42_740, totalEarnings
    ]

    private static let weekAnchors = [
        40_820.0, 41_200, 42_300, 43_800, 45_100, 45_420, 44_700,
        43_100, 41_600, 40_700, 40_300, 40_900, 41_800, 42_600,
        42_200, 41_700, 42_100, 43_000, 43_680, 43_400, 43_050,
        42_900, 42_760, totalEarnings
    ]

    private static let monthAnchors = [
        34_600.0, 35_100, 36_800, 38_600, 39_400, 39_100, 40_200,
        42_500, 45_100, 47_400, 48_200, 47_600, 45_900, 43_200,
        39_800, 36_500, 34_200, 33_100, 34_000, 35_800, 38_100,
        40_700, 43_200, 44_600, 43_900, 43_100, totalEarnings
    ]

    private static let yearAnchors = [
        11_800.0, 14_600, 19_500, 26_900, 34_800, 39_600, 37_200,
        31_500, 26_200, 23_800, 25_400, 29_700, 34_600, 40_800,
        46_900, 52_300, 55_800, 54_600, 50_200, 43_700, 36_900,
        32_800, 34_200, 38_600, 43_900, 47_100, 45_900, 44_100,
        43_500, totalEarnings
    ]

    private static let dayTrend = MonotoneTrend(values: dayAnchors)
    private static let weekTrend = MonotoneTrend(values: weekAnchors)
    private static let monthTrend = MonotoneTrend(values: monthAnchors)
    private static let yearTrend = MonotoneTrend(values: yearAnchors)

    private static let daySeries = makeSeries(for: .day)
    private static let weekSeries = makeSeries(for: .week)
    private static let monthSeries = makeSeries(for: .month)
    private static let yearSeries = makeSeries(for: .year)

    static func series(for range: EarningsRange) -> EarningsSeries {
        switch range {
        case .day: daySeries
        case .week: weekSeries
        case .month: monthSeries
        case .year: yearSeries
        }
    }

    static func point(for range: EarningsRange, minuteIndex: Int) -> EarningsPoint {
        let clampedIndex = min(max(minuteIndex, 0), range.minuteCount)
        let progress = Double(clampedIndex) / Double(range.minuteCount)
        let baseline = trendValue(for: range, progress: progress)
        let envelope = sin(.pi * progress)
        let minute = Double(clampedIndex)

        let value = zip(sources, sourceProfiles).reduce(0.0) { result, pair in
            let (source, profile) = pair
            let share = source.earnings / totalEarnings
            let shortWave = sin(2 * .pi * minute / profile.shortCycleMinutes + profile.phase)
            let rangeWave = sin(2 * .pi * progress * profile.rangeCycles + profile.phase * 0.6)
            let modulation = envelope * profile.amplitude * (shortWave * 0.25 + rangeWave * 0.75)
            return result + baseline * share * (1 + modulation)
        }

        let date = referenceDate.addingTimeInterval(TimeInterval(clampedIndex - range.minuteCount) * 60)
        return EarningsPoint(date: date, value: clampedIndex == range.minuteCount ? totalEarnings : value)
    }

    private static func trend(for range: EarningsRange) -> MonotoneTrend {
        switch range {
        case .day: dayTrend
        case .week: weekTrend
        case .month: monthTrend
        case .year: yearTrend
        }
    }

    private static func trendValue(for range: EarningsRange, progress: Double) -> Double {
        trend(for: range).value(at: progress)
    }

    private static func makeSeries(for range: EarningsRange) -> EarningsSeries {
        let firstPoint = point(for: range, minuteIndex: 0)
        let lastPoint = point(for: range, minuteIndex: range.minuteCount)
        var chartPoints = [firstPoint]
        var minimumValue = min(firstPoint.value, lastPoint.value)
        var maximumValue = max(firstPoint.value, lastPoint.value)
        var bucketStart = 1

        while bucketStart < range.minuteCount {
            let bucketEnd = min(bucketStart + range.chartBucketMinutes, range.minuteCount)
            var valueSum = 0.0
            var sampleCount = 0

            for minuteIndex in bucketStart..<bucketEnd {
                let point = point(for: range, minuteIndex: minuteIndex)
                valueSum += point.value
                sampleCount += 1
                minimumValue = min(minimumValue, point.value)
                maximumValue = max(maximumValue, point.value)
            }

            let representativeIndex = (bucketStart + bucketEnd - 1) / 2
            let representativeDate = referenceDate.addingTimeInterval(
                TimeInterval(representativeIndex - range.minuteCount) * 60
            )
            chartPoints.append(
                EarningsPoint(
                    date: representativeDate,
                    value: valueSum / Double(sampleCount)
                )
            )
            bucketStart = bucketEnd
        }

        chartPoints.append(lastPoint)

        return EarningsSeries(
            minuteCount: range.minuteCount,
            chartPoints: chartPoints,
            valueDomain: minimumValue...maximumValue,
            firstPoint: firstPoint,
            lastPoint: lastPoint
        )
    }
}

struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedRange: EarningsRange = .month
    @State private var selectedPoint: EarningsPoint?
    @State private var displayedPoint: EarningsPoint?
    @State private var revealProgress = 0.0
    @State private var revealCycle = 0
    @State private var shouldRevealAfterBackground = false

    private var earningsSeries: EarningsSeries {
        EarningsMockData.series(for: selectedRange)
    }

    private var chartPoints: [EarningsPoint] {
        earningsSeries.chartPoints
    }

    private var displayedEarnings: Double {
        displayedPoint?.value ?? EarningsMockData.totalEarnings
    }

    private var periodGain: Double {
        displayedEarnings - earningsSeries.firstPoint.value
    }

    private var periodChange: Double {
        let firstValue = earningsSeries.firstPoint.value
        guard firstValue > 0 else {
            return 0
        }

        return periodGain / firstValue * 100
    }

    private var chartDomain: ClosedRange<Double> {
        let lowerValue = earningsSeries.valueDomain.lowerBound
        let upperValue = earningsSeries.valueDomain.upperBound
        let spread = Swift.max(upperValue - lowerValue, 1)
        let lowerBound = Swift.max(0, lowerValue - spread * 0.12)

        return lowerBound...(upperValue + spread * 0.10)
    }

    private var highlightedProgress: Double {
        guard
            let selectedPoint,
            let firstDate = chartPoints.first?.date,
            let lastDate = chartPoints.last?.date
        else {
            return 1
        }

        let fullInterval = lastDate.timeIntervalSince(firstDate)
        guard fullInterval > 0 else { return 1 }

        return min(max(selectedPoint.date.timeIntervalSince(firstDate) / fullInterval, 0), 1)
    }

    private var revealTaskID: String {
        "\(selectedRange.rawValue)-\(revealCycle)"
    }

    private var dateLabelPoints: [EarningsPoint] {
        return [0.0, 0.25, 0.5, 0.75, 1.0].map { progress in
            EarningsMockData.point(
                for: selectedRange,
                minuteIndex: Int((Double(earningsSeries.minuteCount) * progress).rounded())
            )
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
        .task(id: revealTaskID) {
            await Task.yield()
            guard !Task.isCancelled, revealProgress < 1 else { return }

            withAnimation(.timingCurve(0.24, 0.68, 0.30, 1, duration: 1.30)) {
                revealProgress = 1
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                selectedPoint = nil
                displayedPoint = nil
                revealProgress = 0
                shouldRevealAfterBackground = true
            } else if newPhase == .active, shouldRevealAfterBackground {
                shouldRevealAfterBackground = false
                revealCycle += 1
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
                    .contentTransition(.numericText(value: periodGain))
                    .animation(.easeOut(duration: 0.30), value: periodGain)

                Text("\(periodChange.percentText) · \(selectedRange.rawValue)")
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: periodChange))
                    .animation(.easeOut(duration: 0.30), value: periodChange)
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .padding(.top, 7)
        }
    }

    private var earningsChart: some View {
        ZStack {
            ZStack {
                EarningsCurveLayer(
                    points: chartPoints,
                    chartDomain: chartDomain,
                    lineOpacity: 0.035,
                    areaTopOpacity: 0
                )
                .mask {
                    CurveRevealMask(progress: revealProgress)
                }

                EarningsCurveLayer(
                    points: chartPoints,
                    chartDomain: chartDomain,
                    lineOpacity: 0.96,
                    areaTopOpacity: 0.27
                )
                .mask {
                    CurveSelectionMask(progress: highlightedProgress)
                }
                .mask {
                    CurveRevealMask(progress: revealProgress)
                }
            }
            .compositingGroup()
            .mask {
                CurveEdgeFadeMask()
            }

            EarningsCurveInteractionLayer(
                chartPoints: chartPoints,
                chartDomain: chartDomain,
                range: selectedRange,
                minuteCount: earningsSeries.minuteCount,
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
                    guard range != selectedRange else { return }
                    selectedPoint = nil
                    displayedPoint = nil
                    revealProgress = 0
                    selectedRange = range
                } label: {
                    Text(range.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedRange == range ? Color.accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            selectedRange == range ? Color.accentColor.opacity(0.15) : .clear,
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

private struct CurveRevealMask: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let revealedWidth = geometry.size.width * min(max(progress, 0), 1)

            Rectangle()
                .fill(.white)
                .frame(width: revealedWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct CurveSelectionMask: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let selectedWidth = geometry.size.width * min(max(progress, 0), 1)
            let fadeWidth = min(max(geometry.size.width - selectedWidth, 0), 26)

            if selectedWidth >= geometry.size.width {
                Color.white
            } else if selectedWidth > 0 {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(.white)
                        .frame(width: selectedWidth)

                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: fadeWidth)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                Color.clear
            }
        }
    }
}

private struct CurveEdgeFadeMask: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.03),
                .init(color: .white.opacity(0.42), location: 0.10),
                .init(color: .white, location: 0.17),
                .init(color: .white, location: 0.83),
                .init(color: .white.opacity(0.42), location: 0.90),
                .init(color: .clear, location: 0.97),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct EarningsCurveLayer: View {
    let points: [EarningsPoint]
    let chartDomain: ClosedRange<Double>
    let lineOpacity: Double
    let areaTopOpacity: Double

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Date", point.date),
                yStart: .value("Baseline", chartDomain.lowerBound),
                yEnd: .value("Earnings", point.value)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: Color.accentColor.opacity(areaTopOpacity), location: 0),
                        .init(color: Color.accentColor.opacity(areaTopOpacity * 0.38), location: 0.36),
                        .init(color: Color.accentColor.opacity(0), location: 0.72),
                        .init(color: Color.accentColor.opacity(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .alignsMarkStylesWithPlotArea()

            LineMark(
                x: .value("Date", point.date),
                y: .value("Earnings", point.value)
            )
            .interpolationMethod(.monotone)
            .lineStyle(
                StrokeStyle(
                    lineWidth: 2.5,
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
    let chartPoints: [EarningsPoint]
    let chartDomain: ClosedRange<Double>
    let range: EarningsRange
    let minuteCount: Int
    @Binding var selectedPoint: EarningsPoint?
    @Binding var displayedPoint: EarningsPoint?
    @State private var hapticStep = 0
    @State private var lastHapticCell: Int?
    @State private var lastDisplayedCell: Int?

    var body: some View {
        Chart(chartPoints) { point in
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
                                            plotWidth: plotRect.width
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
        let start = chartPoints.first?.date ?? .now
        let end = chartPoints.last?.date ?? start.addingTimeInterval(1)
        return start...end
    }

    private func updateSelection(at xPosition: CGFloat, plotWidth: CGFloat) {
        guard plotWidth > 0, minuteCount > 0 else { return }

        let clampedX = min(max(xPosition, 0), plotWidth)
        let progress = Double(clampedX / plotWidth)
        let minuteIndex = Int((progress * Double(minuteCount)).rounded())
        let nextPoint = EarningsMockData.point(for: range, minuteIndex: minuteIndex)
        let hapticCell = interactionCell(
            for: minuteIndex,
            plotWidth: plotWidth,
            cellWidth: 5
        )

        if hapticCell != lastHapticCell {
            lastHapticCell = hapticCell
            hapticStep += 1
        }

        let displayedCell = interactionCell(
            for: minuteIndex,
            plotWidth: plotWidth,
            cellWidth: 20
        )
        if displayedCell != lastDisplayedCell {
            lastDisplayedCell = displayedCell
            displayedPoint = nextPoint
        }

        guard nextPoint.id != selectedPoint?.id else { return }

        selectedPoint = nextPoint
    }

    private func interactionCell(
        for minuteIndex: Int,
        plotWidth: CGFloat,
        cellWidth: CGFloat
    ) -> Int {
        let cellCount = max(Int(plotWidth / cellWidth), 1)
        return Int(Double(minuteIndex) / Double(minuteCount) * Double(cellCount))
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
