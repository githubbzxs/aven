import SwiftUI

struct DashboardView: View {
    @Environment(Store.self) private var store
    @Binding var range: EarningsRange

    @State private var selection: ChartSelection?
    @State private var displayed: ChartSelection?
    @State private var revealProgress = 1.0
    @State private var revealCycle = 0

    private var overview: Overview? { store.overviews[range] }
    private var curve: CurveData? { store.curve(source: nil, range: range) }

    var body: some View {
        PageScroll(refresh: { await store.refreshMain(range: range) }) {
            header
            EarningsCurveChart(data: curve, range: range, revealProgress: revealProgress, selection: $selection, displayed: $displayed)
                .padding(.top, 22)
            ChartAxisLabels(data: curve, range: range)
            RangeSelector(selection: $range) { _ in
                selection = nil
                displayed = nil
                revealProgress = 0
                revealCycle += 1
            }
            .padding(.top, 17)

            StatusLine()

            if let overview {
                sourcesSection(overview)
            }
            activitySection
        }
        .task(id: "\(revealCycle)-\(curve != nil)") {
            await Task.yield()
            guard !Task.isCancelled, revealProgress < 1, curve != nil else { return }
            withAnimation(.timingCurve(0.24, 0.68, 0.30, 1, duration: EarningsCurveChart.revealDuration(for: curve))) {
                revealProgress = 1
            }
        }
        .accessibilityIdentifier("screen.dashboard")
    }

    // MARK: - 顶部数字

    private var headlineValue: Double? {
        displayed?.value ?? curve?.total ?? overview?.total
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(headlineValue.map { store.money($0) } ?? "—")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .tracking(-1.25)
                .monospacedDigit()
                .contentTransition(.numericText(value: headlineValue ?? 0))
                .animation(.easeOut(duration: 0.30), value: headlineValue)

            HStack(spacing: 7) {
                if let headlineValue {
                    Text(store.secondaryMoney(headlineValue))
                        .foregroundStyle(AppTheme.tone(headlineValue))
                        .contentTransition(.numericText(value: headlineValue))
                        .animation(.easeOut(duration: 0.30), value: headlineValue)
                }
                Text(caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .padding(.top, 7)
        }
    }

    private var caption: String {
        if let displayed, let curve {
            return "· " + displayed.date.crosshairText(span: curve.end.timeIntervalSince(curve.start))
        }
        return "· " + range.caption
    }

    // MARK: - 来源

    private func sourcesSection(_ overview: Overview) -> some View {
        let rows = overview.sources
            .filter { !$0.retired || abs($0.pnl) >= 0.005 }
            .sorted { $0.pnl > $1.pnl }
        let maxMagnitude = rows.map { abs($0.pnl) }.max() ?? 0

        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader("来源 · \(range.caption)")
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, source in
                NavigationLink(value: Route.source(source.id)) {
                    DashboardSourceRow(source: source, maxMagnitude: maxMagnitude)
                }
                .buttonStyle(.plain)
                if index < rows.count - 1 {
                    Hairline(leading: 48)
                }
            }
        }
    }

    // MARK: - 动态

    private var activitySection: some View {
        let entries = FeedEntry.group(store.feed, names: store.sourceNames)
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader("动态") {
                if !entries.isEmpty {
                    NavigationLink(value: Route.feed) {
                        Text("全部")
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
            if entries.isEmpty {
                Text("还没有动态")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 16)
            }
            ForEach(Array(entries.prefix(10).enumerated()), id: \.element.id) { index, entry in
                FeedRow(entry: entry)
                if index < min(entries.count, 10) - 1 {
                    Hairline(leading: 44)
                }
            }
        }
    }
}

private struct DashboardSourceRow: View {
    @Environment(Store.self) private var store
    let source: SourceSummary
    let maxMagnitude: Double

    var body: some View {
        HStack(spacing: 12) {
            SourceIcon(id: source.id, size: 34, dimmed: source.retired)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(source.name)
                        .font(.body.weight(.medium))
                    HealthDot(health: source.health)
                    Spacer(minLength: 8)
                    Text(store.money(source.pnl, signed: true))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.tone(source.pnl))
                }
                ShareBar(value: source.pnl, maxMagnitude: maxMagnitude)
                HStack {
                    Text(caption)
                    Spacer()
                    if let est = source.est {
                        Text("预估 \(store.money(est[0], signed: true)) ～ \(store.money(est[1], signed: true))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var caption: String {
        if source.daily { return "按天记账" }
        return "\(source.count) \(SourceStyle.unit(for: source.id))"
    }
}

// MARK: - 动态

/// 动态列表的一行：同一来源连续的逐笔成交并成一行，告警、阶梯、里程碑、日报晚报各占一行
struct FeedEntry: Identifiable {
    let id: String
    let kind: String
    let src: String?
    let title: String
    let detail: String?
    let sourceName: String?
    let pnl: Double?
    let date: Date
    let count: Int

    static func group(_ items: [FeedItem], names: [String: String]) -> [FeedEntry] {
        var out: [FeedEntry] = []
        for item in items {
            let name = item.src.flatMap { names[$0] }
            if item.kind == "trade", let last = out.last, last.kind == "trade", last.src == item.src {
                let count = last.count + 1
                out[out.count - 1] = FeedEntry(
                    id: last.id, kind: "trade", src: item.src, title: "\(count) \(SourceStyle.unit(for: item.src ?? ""))成交",
                    detail: nil, sourceName: name, pnl: (last.pnl ?? 0) + (item.pnl ?? 0), date: last.date, count: count
                )
                continue
            }
            out.append(FeedEntry(
                id: "\(item.kind)-\(item.ts)-\(item.src ?? "")", kind: item.kind, src: item.src, title: item.title,
                detail: item.body, sourceName: name, pnl: item.pnl, date: Date(timeIntervalSince1970: item.ts), count: 1
            ))
        }
        return out
    }

    var symbol: String {
        switch kind {
        case "alert": "exclamationmark.triangle.fill"
        case "step": "flag.fill"
        case "milestone": "star.fill"
        case "report": "doc.text.fill"
        default: SourceStyle.symbol(for: src ?? "")
        }
    }
}

struct FeedRow: View {
    @Environment(Store.self) private var store
    let entry: FeedEntry
    var expanded = false

    var body: some View {
        Group {
            if let src = entry.src {
                NavigationLink(value: Route.source(src)) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(entry.kind == "alert" ? AppTheme.warning : Color.accentColor)
                .frame(width: 30, height: 30)
                .background((entry.kind == "alert" ? AppTheme.warning : Color.accentColor).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(expanded ? nil : 2)
                    Spacer(minLength: 8)
                    if let pnl = entry.pnl {
                        Text(store.money(pnl, signed: true))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.tone(pnl))
                    }
                }
                if expanded, let detail = entry.detail, entry.kind != "trade" {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text([entry.sourceName, entry.date.feedText].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct FeedView: View {
    @Environment(Store.self) private var store

    var body: some View {
        let entries = FeedEntry.group(store.feed, names: store.sourceNames)
        PageScroll(refresh: { await store.refreshFeed() }) {
            PageTitle(title: "动态", subtitle: "告警、阶梯提醒、日报晚报和逐笔成交")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    FeedRow(entry: entry, expanded: true)
                    if index < entries.count - 1 {
                        Hairline(leading: 42)
                    }
                }
            }
            .padding(.top, 18)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.refreshFeed() }
    }
}

/// 出错时在周期选择下面显示一行小字
struct StatusLine: View {
    @Environment(Store.self) private var store

    var body: some View {
        if let error = store.lastError {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                Text(error + (store.lastUpdated.map { " · 上次更新 \($0.feedText)" } ?? ""))
            }
            .font(.caption)
            .foregroundStyle(AppTheme.warning)
            .padding(.top, 10)
        }
    }
}
