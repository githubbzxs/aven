import Charts
import SwiftUI
import UIKit

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

private struct MarketTextureProfile {
    let seed: Double
    let amplitude: Double
    let valueSpan: Double
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
        42_180.0, 42_110, 42_145, 42_230, 42_195, 42_260, 42_340,
        42_410, 42_365, 42_120, 42_090, 42_130, 42_075, 42_160,
        42_115, 42_230, 42_205, 42_355, 42_310, 42_420, 42_385,
        42_520, 42_470, 42_610, 42_540, 42_700, 42_660, 42_920,
        43_180, 43_050, 43_260, 43_170, 43_390, 43_520, 43_300,
        42_980, 42_860, 43_040, 43_280, 43_460, 43_330, 43_210,
        43_160, 43_050, 42_950, 42_720, 42_690, totalEarnings
    ]

    private static let weekAnchors = [
        40_940.0, 41_180, 41_720, 42_460, 43_250, 43_820, 43_540,
        42_900, 42_240, 41_420, 40_980, 40_620, 40_480, 40_760,
        40_590, 40_940, 41_360, 41_180, 41_720, 42_250, 42_060,
        42_680, 42_410, 42_980, 43_560, 43_220, 43_880, 44_160,
        43_620, 42_940, 42_380, 42_120, 42_460, 42_910, 43_240,
        43_020, 42_860, totalEarnings
    ]

    private static let monthAnchors = [
        35_800.0, 35_250, 35_600, 36_400, 37_200, 38_100, 37_500,
        34_900, 34_700, 35_100, 34_650, 35_400, 35_050, 36_000,
        35_600, 36_800, 37_300, 38_200, 39_800, 39_200, 40_600,
        40_100, 41_400, 40_300, 39_700, 41_100, 42_600, 42_000,
        44_900, 43_800, 45_700, 44_900, 47_300, 48_900, 46_200,
        42_900, 42_100, 43_800, 46_700, 45_100, 44_800, 44_100,
        43_900, 42_650, totalEarnings
    ]

    private static let yearAnchors = [
        12_200.0, 13_100, 14_800, 17_600, 20_900, 24_700, 28_300,
        31_900, 34_600, 33_200, 30_100, 27_400, 25_900, 27_200,
        29_800, 33_600, 37_900, 41_500, 44_300, 42_100, 39_600,
        41_800, 46_400, 50_900, 54_600, 52_300, 47_800, 42_900,
        38_500, 35_900, 37_200, 40_600, 44_900, 48_200, 46_700,
        43_600, 41_900, 44_200, 46_100, 45_300, 43_800, totalEarnings
    ]

    private static let dayTextureProfile = makeTextureProfile(
        values: dayAnchors,
        seed: 7.3,
        amplitude: 0.026
    )
    private static let weekTextureProfile = makeTextureProfile(
        values: weekAnchors,
        seed: 19.1,
        amplitude: 0.020
    )
    private static let monthTextureProfile = makeTextureProfile(
        values: monthAnchors,
        seed: 31.7,
        amplitude: 0.016
    )
    private static let yearTextureProfile = makeTextureProfile(
        values: yearAnchors,
        seed: 47.9,
        amplitude: 0.012
    )

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

        let sourceValue = zip(sources, sourceProfiles).reduce(0.0) { result, pair in
            let (source, profile) = pair
            let share = source.earnings / totalEarnings
            let shortWave = sin(2 * .pi * minute / profile.shortCycleMinutes + profile.phase)
            let rangeWave = sin(2 * .pi * progress * profile.rangeCycles + profile.phase * 0.6)
            let modulation = envelope * profile.amplitude * (shortWave * 0.25 + rangeWave * 0.75)
            return result + baseline * share * (1 + modulation)
        }
        let value = sourceValue + marketTexture(for: range, progress: progress)

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

    private static func makeTextureProfile(
        values: [Double],
        seed: Double,
        amplitude: Double
    ) -> MarketTextureProfile {
        let lowerValue = values.min() ?? 0
        let upperValue = values.max() ?? lowerValue
        return MarketTextureProfile(
            seed: seed,
            amplitude: amplitude,
            valueSpan: max(upperValue - lowerValue, 1)
        )
    }

    private static func textureProfile(for range: EarningsRange) -> MarketTextureProfile {
        switch range {
        case .day: dayTextureProfile
        case .week: weekTextureProfile
        case .month: monthTextureProfile
        case .year: yearTextureProfile
        }
    }

    private static func marketTexture(for range: EarningsRange, progress: Double) -> Double {
        let profile = textureProfile(for: range)
        let slowNoise = smoothNoise(at: progress * 31, seed: profile.seed)
        let mediumNoise = smoothNoise(at: progress * 83, seed: profile.seed + 17.3)
        let fastNoise = smoothNoise(at: progress * 157, seed: profile.seed + 41.9)
        let activityNoise = abs(smoothNoise(at: progress * 9, seed: profile.seed + 83.1))
        let activity = 0.72 + activityNoise * 0.28
        let texture = slowNoise * 0.58 + mediumNoise * 0.30 + fastNoise * 0.12

        return sin(.pi * progress) * profile.valueSpan * profile.amplitude * activity * texture
    }

    private static func smoothNoise(at position: Double, seed: Double) -> Double {
        let lowerPosition = floor(position)
        let fraction = position - lowerPosition
        let easedFraction = fraction * fraction * fraction * (fraction * (fraction * 6 - 15) + 10)
        let lowerValue = signedNoiseSample(at: lowerPosition, seed: seed)
        let upperValue = signedNoiseSample(at: lowerPosition + 1, seed: seed)
        return lowerValue + (upperValue - lowerValue) * easedFraction
    }

    private static func signedNoiseSample(at position: Double, seed: Double) -> Double {
        let rawValue = sin(position * 12.9898 + seed * 78.233) * 43_758.5453
        return (rawValue - floor(rawValue)) * 2 - 1
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
    @State private var selectedRange: EarningsRange = .month
    @State private var selectedPoint: EarningsPoint?
    @State private var displayedPoint: EarningsPoint?
    @State private var revealProgress = 1.0
    @State private var revealCycle = 0
    @State private var rangeScrubIndex: Int?
    @State private var rangeHighlightVisible = false
    @State private var rangeHighlightCycle = 0
    @State private var rangeHapticGenerator = UIImpactFeedbackGenerator(style: .heavy)

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
        chartDomain(for: earningsSeries)
    }

    private func chartDomain(for series: EarningsSeries) -> ClosedRange<Double> {
        let lowerValue = series.valueDomain.lowerBound
        let upperValue = series.valueDomain.upperBound
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

    private var revealDuration: Double {
        guard
            chartPoints.count > 1,
            let firstPoint = chartPoints.first,
            let lastPoint = chartPoints.last
        else {
            return 1.20
        }

        let dateSpan = max(lastPoint.date.timeIntervalSince(firstPoint.date), 1)
        let valueSpan = max(chartDomain.upperBound - chartDomain.lowerBound, 1)
        let chartAspectRatio = 252.0 / 353.0

        let pathLength = zip(chartPoints, chartPoints.dropFirst()).reduce(0.0) { length, pair in
            let horizontalDistance = pair.1.date.timeIntervalSince(pair.0.date) / dateSpan
            let verticalDistance = (pair.1.value - pair.0.value) / valueSpan * chartAspectRatio
            return length + (horizontalDistance * horizontalDistance + verticalDistance * verticalDistance).squareRoot()
        }

        return min(max(1.20 + (pathLength - 1.60) * 0.72, 1.20), 1.60)
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
        .task(id: revealCycle) {
            await Task.yield()
            guard !Task.isCancelled, revealProgress < 1 else { return }

            withAnimation(.timingCurve(0.24, 0.68, 0.30, 1, duration: revealDuration)) {
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
                    lineOpacity: 0.04,
                    glowOpacity: 0
                )
                .mask {
                    CurveRevealMask(progress: revealProgress)
                }

                EarningsCurveLayer(
                    points: chartPoints,
                    chartDomain: chartDomain,
                    lineOpacity: 0.96,
                    glowOpacity: 0.24
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
            ForEach(Array(dateLabelPoints.enumerated()), id: \.offset) { index, point in
                Text(point.date.axisText(for: selectedRange))
                    .contentTransition(.opacity)
                    .frame(
                        maxWidth: .infinity,
                        alignment: index == 0 ? .leading : index == dateLabelPoints.count - 1 ? .trailing : .center
                    )
            }
        }
        .font(.caption2)
        .monospacedDigit()
        .foregroundStyle(.tertiary)
        .animation(.easeInOut(duration: 0.36), value: selectedRange)
        .padding(.top, 5)
    }

    private var rangeSelector: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(EarningsRange.allCases) { range in
                    VStack(spacing: 5) {
                        Text(range.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                selectedRange == range && rangeHighlightVisible
                                    ? Color.accentColor
                                    : .secondary
                            )

                        if selectedRange == range {
                            Circle()
                                .fill(
                                    rangeHighlightVisible
                                        ? Color.accentColor
                                        : Color.secondary.opacity(0.34)
                                )
                                .frame(width: 4, height: 4)
                                .shadow(
                                    color: rangeHighlightVisible
                                        ? Color.accentColor.opacity(0.38)
                                        : .clear,
                                    radius: 2.5
                                )
                        } else {
                            Color.clear
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .contentShape(Rectangle())
                    .accessibilityElement()
                    .accessibilityLabel("Show \(range.rawValue) earnings")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(selectedRange == range ? .isSelected : [])
                    .accessibilityAction {
                        selectRange(range)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        scrubRange(
                            at: gesture.location.x,
                            selectorWidth: geometry.size.width
                        )
                    }
                    .onEnded { _ in
                        rangeScrubIndex = nil
                        rangeHapticGenerator.prepare()
                    }
            )
        }
        .frame(height: 34)
        .task(id: rangeHighlightCycle) {
            guard rangeHighlightVisible else { return }

            do {
                try await Task.sleep(nanoseconds: 850_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.42)) {
                rangeHighlightVisible = false
            }
        }
        .onAppear {
            rangeHapticGenerator.prepare()
        }
        .padding(.top, 17)
    }

    private func scrubRange(at xPosition: CGFloat, selectorWidth: CGFloat) {
        guard selectorWidth > 0 else { return }

        let ranges = EarningsRange.allCases
        let segmentWidth = selectorWidth / CGFloat(ranges.count)
        guard segmentWidth > 0 else { return }

        let clampedX = min(max(xPosition, 0), selectorWidth - 0.001)
        let rawIndex = min(max(Int(clampedX / segmentWidth), 0), ranges.count - 1)

        guard let currentIndex = rangeScrubIndex else {
            rangeScrubIndex = rawIndex
            rangeHapticGenerator.prepare()
            selectRange(ranges[rawIndex])
            return
        }

        let hysteresis = min(segmentWidth * 0.12, 12)
        var nextIndex = currentIndex

        while nextIndex < ranges.count - 1 {
            let boundary = CGFloat(nextIndex + 1) * segmentWidth
            guard clampedX >= boundary + hysteresis else { break }
            nextIndex += 1
        }

        while nextIndex > 0 {
            let boundary = CGFloat(nextIndex) * segmentWidth
            guard clampedX <= boundary - hysteresis else { break }
            nextIndex -= 1
        }

        guard nextIndex != currentIndex else { return }
        rangeScrubIndex = nextIndex
        selectRange(ranges[nextIndex])
    }

    private func selectRange(_ range: EarningsRange) {
        if range != selectedRange {
            selectedPoint = nil
            displayedPoint = nil
            revealProgress = 0
            selectedRange = range
            revealCycle += 1
        }

        rangeHighlightVisible = true
        rangeHighlightCycle += 1
        rangeHapticGenerator.impactOccurred(intensity: 0.6)
        rangeHapticGenerator.prepare()
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
            let fadeWidth = min(max(geometry.size.width - selectedWidth, 0), 6)

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
    let glowOpacity: Double

    var body: some View {
        ZStack {
            if glowOpacity > 0 {
                EarningsCurveGlow(
                    points: points,
                    chartDomain: chartDomain,
                    opacity: glowOpacity
                )
            }

            EarningsCurveLine(
                points: points,
                chartDomain: chartDomain,
                lineWidth: 2.2,
                opacity: lineOpacity
            )
        }
    }
}

private struct EarningsCurveGlow: View {
    let points: [EarningsPoint]
    let chartDomain: ClosedRange<Double>
    let opacity: Double

    var body: some View {
        EarningsCurveLine(
            points: points,
            chartDomain: chartDomain,
            lineWidth: 5.5,
            opacity: opacity
        )
        .blur(radius: 3)
        .allowsHitTesting(false)
    }
}

private struct EarningsCurveLine: View {
    let points: [EarningsPoint]
    let chartDomain: ClosedRange<Double>
    let lineWidth: CGFloat
    let opacity: Double

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Earnings", point.value)
            )
            .interpolationMethod(.monotone)
            .lineStyle(
                StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .foregroundStyle(Color.accentColor.opacity(opacity))
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
