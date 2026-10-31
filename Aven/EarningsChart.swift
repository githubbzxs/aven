import Charts
import SwiftUI
import UIKit

struct ChartPoint: Identifiable, Equatable {
    let date: Date
    let value: Double

    var id: Date { date }
}

/// 累计收益曲线：接口给逐笔事件，这里累加成阶梯函数，再均匀取样成绘图点；
/// 拖动时按真实时刻查阶梯函数，读到的是那一刻真实的累计值，不受取样影响。
struct CurveData: Equatable {
    let start: Date
    let end: Date
    let points: [ChartPoint]
    let extraLines: [[ChartPoint]]
    let domain: ClosedRange<Double>
    let total: Double
    private let times: [Double]
    private let sums: [Double]

    init(series: Series, samples: Int = 320) {
        let t0 = series.t0
        let t1 = max(series.t1, series.t0 + 60)
        start = Date(timeIntervalSince1970: t0)
        end = Date(timeIntervalSince1970: t1)

        let (times, sums) = Self.cumulative(series.events)
        self.times = times
        self.sums = sums
        total = sums.last ?? 0

        let grid = (0...samples).map { t0 + (t1 - t0) * Double($0) / Double(samples) }
        points = grid.map { ChartPoint(date: Date(timeIntervalSince1970: $0), value: Self.lookup($0, times, sums)) }

        // Ondo挂单的预估线：已实现 + 估算奖励（保守、乐观两条）
        extraLines = (series.est ?? []).map { estEvents in
            let (estTimes, estSums) = Self.cumulative(series.events + estEvents)
            return grid.map { ChartPoint(date: Date(timeIntervalSince1970: $0), value: Self.lookup($0, estTimes, estSums)) }
        }

        let values = points.map(\.value) + extraLines.flatMap { $0.map(\.value) } + [0]
        domain = (values.min() ?? 0)...(values.max() ?? 1)
    }

    func value(at date: Date) -> Double {
        Self.lookup(date.timeIntervalSince1970, times, sums)
    }

    var crossesZero: Bool {
        domain.lowerBound < -0.005 && points.contains { $0.value < -0.005 }
    }

    private static func cumulative(_ events: [[Double]]) -> ([Double], [Double]) {
        let sorted = events.filter { $0.count >= 2 }.sorted { $0[0] < $1[0] }
        var times: [Double] = []
        var sums: [Double] = []
        var running = 0.0
        times.reserveCapacity(sorted.count)
        sums.reserveCapacity(sorted.count)
        for event in sorted {
            running += event[1]
            times.append(event[0])
            sums.append(running)
        }
        return (times, sums)
    }

    /// 时刻 t（含）之前的累计值：二分找最后一个不晚于 t 的事件
    private static func lookup(_ t: Double, _ times: [Double], _ sums: [Double]) -> Double {
        var low = 0
        var high = times.count
        while low < high {
            let mid = (low + high) / 2
            if times[mid] <= t { low = mid + 1 } else { high = mid }
        }
        return low == 0 ? 0 : sums[low - 1]
    }
}

/// 拖动时的选中点，顶部数字跟着它走
struct ChartSelection: Equatable {
    let date: Date
    let value: Double
}

/// 收益曲线：紫色细线加微光；拖动时已划过部分高亮、未划过部分压暗；切换周期时从左向右绘入。
struct EarningsCurveChart: View {
    let data: CurveData?
    let range: EarningsRange
    let revealProgress: Double
    @Binding var selection: ChartSelection?
    @Binding var displayed: ChartSelection?

    static let height: CGFloat = 252

    var body: some View {
        ZStack {
            if let data {
                let domain = paddedDomain(data.domain)

                if data.crossesZero {
                    ZeroLine(data: data, domain: domain)
                        .mask { CurveRevealMask(progress: revealProgress) }
                }

                ForEach(Array(data.extraLines.enumerated()), id: \.offset) { index, line in
                    CurveLine(points: line, start: data.start, end: data.end, domain: domain, lineWidth: 1.4,
                              color: index == 0 ? AppTheme.estLow : AppTheme.estHigh, opacity: selection == nil ? 0.75 : 0.25, dash: [3, 3])
                        .mask { CurveRevealMask(progress: revealProgress) }
                }

                ZStack {
                    CurveLayer(data: data, domain: domain, lineOpacity: 0.04, glowOpacity: 0)
                        .mask { CurveRevealMask(progress: revealProgress) }

                    CurveLayer(data: data, domain: domain, lineOpacity: 0.96, glowOpacity: 0.24)
                        .mask { CurveSelectionMask(progress: highlightedProgress(data)) }
                        .mask { CurveRevealMask(progress: revealProgress) }
                }
                .compositingGroup()
                .mask { CurveEdgeFadeMask() }

                CurveInteractionLayer(data: data, domain: domain, range: range, selection: $selection, displayed: $displayed)
            }
        }
        .frame(height: Self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("累计收益曲线")
    }

    private func paddedDomain(_ domain: ClosedRange<Double>) -> ClosedRange<Double> {
        let spread = Swift.max(domain.upperBound - domain.lowerBound, 0.5)
        return (domain.lowerBound - spread * 0.12)...(domain.upperBound + spread * 0.10)
    }

    private func highlightedProgress(_ data: CurveData) -> Double {
        guard let selection else { return 1 }
        let span = data.end.timeIntervalSince(data.start)
        guard span > 0 else { return 1 }
        return min(max(selection.date.timeIntervalSince(data.start) / span, 0), 1)
    }

    /// 绘入时长按曲线实际路径长度在 1.20～1.60 秒之间取
    static func revealDuration(for data: CurveData?) -> Double {
        guard let data, data.points.count > 1 else { return 1.20 }
        let span = max(data.end.timeIntervalSince(data.start), 1)
        let valueSpan = max(data.domain.upperBound - data.domain.lowerBound, 0.5)
        let aspect = Double(height) / 353.0
        let length = zip(data.points, data.points.dropFirst()).reduce(0.0) { sum, pair in
            let dx = pair.1.date.timeIntervalSince(pair.0.date) / span
            let dy = (pair.1.value - pair.0.value) / valueSpan * aspect
            return sum + (dx * dx + dy * dy).squareRoot()
        }
        return min(max(1.20 + (length - 1.60) * 0.72, 1.20), 1.60)
    }
}

/// 图表下方 5 个固定槽位的日期，切换周期只换文字并交叉淡化
struct ChartAxisLabels: View {
    let data: CurveData?
    let range: EarningsRange

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                Text(label(index))
                    .contentTransition(.opacity)
                    .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : index == 4 ? .trailing : .center)
            }
        }
        .font(.caption2)
        .monospacedDigit()
        .foregroundStyle(.tertiary)
        .animation(.easeInOut(duration: 0.36), value: range)
        .animation(.easeInOut(duration: 0.36), value: data?.start)
        .padding(.top, 5)
    }

    private func label(_ index: Int) -> String {
        guard let data else { return " " }
        let date = data.start.addingTimeInterval(data.end.timeIntervalSince(data.start) * Double(index) / 4)
        return date.axisText(span: data.end.timeIntervalSince(data.start))
    }
}

// MARK: - 图层

private struct ZeroLine: View {
    let data: CurveData
    let domain: ClosedRange<Double>

    var body: some View {
        Chart {
            RuleMark(y: .value("零", 0))
                .lineStyle(StrokeStyle(lineWidth: 0.6, dash: [2, 4]))
                .foregroundStyle(Color.white.opacity(0.14))
        }
        .chartXScale(domain: data.start...data.end)
        .chartYScale(domain: domain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .allowsHitTesting(false)
    }
}

private struct CurveLayer: View {
    let data: CurveData
    let domain: ClosedRange<Double>
    let lineOpacity: Double
    let glowOpacity: Double

    var body: some View {
        ZStack {
            if glowOpacity > 0 {
                CurveLine(points: data.points, start: data.start, end: data.end, domain: domain, lineWidth: 5.5, color: .accentColor, opacity: glowOpacity)
                    .blur(radius: 3)
            }
            CurveLine(points: data.points, start: data.start, end: data.end, domain: domain, lineWidth: 2.2, color: .accentColor, opacity: lineOpacity)
        }
        .allowsHitTesting(false)
    }
}

private struct CurveLine: View {
    let points: [ChartPoint]
    let start: Date
    let end: Date
    let domain: ClosedRange<Double>
    let lineWidth: CGFloat
    let color: Color
    let opacity: Double
    var dash: [CGFloat] = []

    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("时刻", point.date), y: .value("收益", point.value))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round, dash: dash))
                .foregroundStyle(color.opacity(opacity))
        }
        .chartXScale(domain: start...end)
        .chartYScale(domain: domain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { $0.background(.clear) }
        .allowsHitTesting(false)
    }
}

private struct CurveInteractionLayer: View {
    let data: CurveData
    let domain: ClosedRange<Double>
    let range: EarningsRange
    @Binding var selection: ChartSelection?
    @Binding var displayed: ChartSelection?
    @State private var hapticStep = 0
    @State private var lastHapticCell: Int?
    @State private var lastDisplayedCell: Int?

    var body: some View {
        Chart(data.points) { point in
            LineMark(x: .value("时刻", point.date), y: .value("收益", point.value))
                .foregroundStyle(.clear)
        }
        .chartXScale(domain: data.start...data.end)
        .chartYScale(domain: domain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { $0.background(.clear) }
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
                                        updateSelection(at: gesture.location.x - plotRect.minX, plotWidth: plotRect.width)
                                    }
                                    .onEnded { _ in
                                        lastHapticCell = nil
                                        lastDisplayedCell = nil
                                        withAnimation(.easeOut(duration: 0.24)) {
                                            selection = nil
                                            displayed = nil
                                        }
                                    }
                            )

                        if let selection,
                           let x = proxy.position(forX: selection.date),
                           let y = proxy.position(forY: selection.value) {
                            indicator(x: plotRect.minX + x, y: plotRect.minY + y, plotRect: plotRect, date: selection.date)
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: hapticStep)
    }

    private func updateSelection(at x: CGFloat, plotWidth: CGFloat) {
        guard plotWidth > 0 else { return }
        let progress = Double(min(max(x, 0), plotWidth) / plotWidth)
        let date = data.start.addingTimeInterval(data.end.timeIntervalSince(data.start) * progress)
        // 按分钟取整，避免同一分钟内反复刷新
        let minute = Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded() * 60)
        let next = ChartSelection(date: min(max(minute, data.start), data.end), value: data.value(at: date))

        let hapticCell = Int(progress * Double(max(Int(plotWidth / 5), 1)))
        if hapticCell != lastHapticCell {
            lastHapticCell = hapticCell
            hapticStep += 1
        }

        let displayedCell = Int(progress * Double(max(Int(plotWidth / 20), 1)))
        if displayedCell != lastDisplayedCell {
            lastDisplayedCell = displayedCell
            displayed = next
        }

        if next != selection {
            selection = next
        }
    }

    @ViewBuilder
    private func indicator(x: CGFloat, y: CGFloat, plotRect: CGRect, date: Date) -> some View {
        let labelX = min(max(x, plotRect.minX + 34), plotRect.maxX - 34)
        let guideTop = plotRect.minY + 24
        let guideBottom = max(guideTop, y - 8)

        Path { path in
            path.move(to: CGPoint(x: x, y: guideTop))
            path.addLine(to: CGPoint(x: x, y: guideBottom))
        }
        .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [2, 3]))

        Text(date.crosshairText(span: data.end.timeIntervalSince(data.start)))
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .position(x: labelX, y: plotRect.minY + 8)

        Circle()
            .fill(Color.accentColor.opacity(0.24))
            .frame(width: 20, height: 20)
            .blur(radius: 4)
            .position(x: x, y: y)

        Circle()
            .fill(.white)
            .frame(width: 6, height: 6)
            .shadow(color: Color.accentColor.opacity(0.9), radius: 3)
            .position(x: x, y: y)
    }
}

// MARK: - 遮罩

struct CurveRevealMask: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(.white)
                .frame(width: geometry.size.width * min(max(progress, 0), 1))
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
                    Rectangle().fill(.white).frame(width: selectedWidth)
                    LinearGradient(colors: [.white, .clear], startPoint: .leading, endPoint: .trailing)
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
                .init(color: .clear, location: 0.02),
                .init(color: .white.opacity(0.42), location: 0.07),
                .init(color: .white, location: 0.13),
                .init(color: .white, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - 周期选择

/// 透明滑动分段：只有选中项下方一个 4×4pt 圆点；点按或拖到某项立即变紫，约 0.85 秒后淡回灰色。
/// 支持按住横向连续滑过多个分段，边界有迟滞区；每次选择（含重按当前项）都给 0.6 强度的重力度反馈。
struct RangeSelector: View {
    @Binding var selection: EarningsRange
    var onSelect: (EarningsRange) -> Void = { _ in }

    @State private var scrubIndex: Int?
    @State private var highlightVisible = false
    @State private var highlightCycle = 0
    @State private var haptic = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(EarningsRange.allCases) { range in
                    VStack(spacing: 5) {
                        Text(range.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selection == range && highlightVisible ? Color.accentColor : .secondary)

                        if selection == range {
                            Circle()
                                .fill(highlightVisible ? Color.accentColor : Color.secondary.opacity(0.34))
                                .frame(width: 4, height: 4)
                                .shadow(color: highlightVisible ? Color.accentColor.opacity(0.38) : .clear, radius: 2.5)
                        } else {
                            Color.clear.frame(width: 4, height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .contentShape(Rectangle())
                    .accessibilityElement()
                    .accessibilityLabel(range.caption)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(selection == range ? .isSelected : [])
                    .accessibilityAction { select(range) }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { scrub(at: $0.location.x, width: geometry.size.width) }
                    .onEnded { _ in
                        scrubIndex = nil
                        haptic.prepare()
                    }
            )
        }
        .frame(height: 34)
        .task(id: highlightCycle) {
            guard highlightVisible else { return }
            do { try await Task.sleep(for: .milliseconds(850)) } catch { return }
            withAnimation(.easeOut(duration: 0.42)) { highlightVisible = false }
        }
        .onAppear { haptic.prepare() }
    }

    private func scrub(at x: CGFloat, width: CGFloat) {
        let ranges = EarningsRange.allCases
        guard width > 0 else { return }
        let segment = width / CGFloat(ranges.count)
        let clampedX = min(max(x, 0), width - 0.001)
        let rawIndex = min(max(Int(clampedX / segment), 0), ranges.count - 1)

        guard let current = scrubIndex else {
            scrubIndex = rawIndex
            haptic.prepare()
            select(ranges[rawIndex])
            return
        }

        let hysteresis = min(segment * 0.12, 12)
        var next = current
        while next < ranges.count - 1, clampedX >= CGFloat(next + 1) * segment + hysteresis { next += 1 }
        while next > 0, clampedX <= CGFloat(next) * segment - hysteresis { next -= 1 }

        guard next != current else { return }
        scrubIndex = next
        select(ranges[next])
    }

    private func select(_ range: EarningsRange) {
        if range != selection {
            selection = range
            onSelect(range)
        }
        highlightVisible = true
        highlightCycle += 1
        haptic.impactOccurred(intensity: 0.6)
        haptic.prepare()
    }
}

// MARK: - 日期文字

extension Date {
    /// 横轴：一天以内显示时分，其余显示月/日
    func axisText(span: TimeInterval) -> String {
        span <= 86_400 * 1.05 ? formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute()) : formatted(.dateTime.month(.defaultDigits).day())
    }

    /// 拖动指示线上方：一天以内显示时分，七天以内显示日期和时分，其余显示日期
    func crosshairText(span: TimeInterval) -> String {
        if span <= 86_400 * 1.05 { return formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute()) }
        if span <= 86_400 * 8 { return formatted(.dateTime.month(.defaultDigits).day().hour(.twoDigits(amPM: .omitted)).minute()) }
        return formatted(.dateTime.year().month(.defaultDigits).day())
    }
}
