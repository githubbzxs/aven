import SwiftUI

struct SourcesView: View {
    @Environment(Store.self) private var store

    private var today: Overview? { store.overviews[.day] }
    private var month: Overview? { store.overviews[.month] }

    var body: some View {
        let sources = today?.sources ?? month?.sources ?? []
        let active = sources.filter { !$0.retired }
        let retired = sources.filter(\.retired)

        PageScroll(refresh: { await store.refreshMain(range: .day) }) {
            PageTitle(
                title: "Sources",
                subtitle: today.map { "\(active.count) 个来源 · 今天 \(store.money($0.today, signed: true))" }
            )

            StatusLine()

            if sources.isEmpty {
                Text(store.isConfigured ? "正在加载…" : "先到 Settings 填接口令牌")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 32)
            }

            if !active.isEmpty {
                HStack {
                    Text("今天")
                    Spacer()
                    Text("近 30 天")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 28)
                .padding(.bottom, 4)

                Hairline()
                rows(active)
            }

            if !retired.isEmpty {
                SectionHeader("已停用")
                rows(retired)
            }
        }
        .accessibilityIdentifier("screen.sources")
    }

    private func rows(_ sources: [SourceSummary]) -> some View {
        ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
            NavigationLink(value: Route.source(source.id)) {
                SourceRow(source: source, monthPnl: month?.sources.first { $0.id == source.id }?.pnl)
            }
            .buttonStyle(.plain)
            if index < sources.count - 1 {
                Hairline(leading: 50)
            }
        }
    }
}

private struct SourceRow: View {
    @Environment(Store.self) private var store
    let source: SourceSummary
    let monthPnl: Double?

    var body: some View {
        HStack(spacing: 14) {
            SourceIcon(id: source.id, dimmed: source.retired)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(source.name)
                        .font(.body.weight(.medium))
                    HealthDot(health: source.health)
                }
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(source.health == .ok ? AnyShapeStyle(.tertiary) : AnyShapeStyle(source.health == .error ? AppTheme.negative : AppTheme.warning))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(store.money(source.today, signed: true))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.tone(source.today))
                if let monthPnl {
                    Text(store.money(monthPnl, signed: true))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .monospacedDigit()
        }
        .padding(.vertical, 15)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var caption: String {
        if let note = source.note, source.health != .ok { return note }
        if source.daily { return "按天记账" + (source.last.map { " · 记到 " + Date(timeIntervalSince1970: $0).formatted(.dateTime.month(.defaultDigits).day()) } ?? "") }
        guard let last = source.last else { return "暂无记录" }
        return "最近一笔 " + Date(timeIntervalSince1970: last).feedText
    }
}

// MARK: - 来源详情

struct SourceDetailView: View {
    @Environment(Store.self) private var store
    let id: String

    @AppStorage("detailRange") private var range: EarningsRange = .week
    @State private var selection: ChartSelection?
    @State private var displayed: ChartSelection?
    @State private var revealProgress = 1.0
    @State private var revealCycle = 0
    @State private var recordLimit = 30
    @State private var showAllDays = false

    private var detail: SourceDetail? { store.detailValue(source: id, range: range) }
    private var curve: CurveData? { store.curve(source: id, range: range) }
    private var name: String { detail?.name ?? store.sourceNames[id] ?? id }

    var body: some View {
        PageScroll(refresh: { await refresh() }) {
            header
            EarningsCurveChart(data: curve, range: range, revealProgress: revealProgress, selection: $selection, displayed: $displayed)
                .padding(.top, 22)
            ChartAxisLabels(data: curve, range: range)
            RangeSelector(selection: $range) { _ in
                selection = nil
                displayed = nil
                revealProgress = 0
                revealCycle += 1
                recordLimit = 30
                showAllDays = false
            }
            .padding(.top, 17)

            StatusLine()

            if let detail {
                if detail.health != .ok, let note = detail.note {
                    Label(note, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(detail.health == .error ? AppTheme.negative : AppTheme.warning)
                        .padding(.top, 18)
                }
                stats(detail)
                if let positions = detail.positions, !positions.isEmpty {
                    PositionsSection(positions: positions)
                }
                if let quota = detail.quota {
                    QuotaSection(quota: quota)
                }
                if detail.parts.count > 1 {
                    partsSection(detail)
                }
                daysSection(detail)
                recordsSection(detail)
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: range) {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .task(id: "\(revealCycle)-\(curve != nil)") {
            await Task.yield()
            guard !Task.isCancelled, revealProgress < 1, curve != nil else { return }
            withAnimation(.timingCurve(0.24, 0.68, 0.30, 1, duration: EarningsCurveChart.revealDuration(for: curve))) {
                revealProgress = 1
            }
        }
    }

    private func refresh() async {
        async let detail: Void = store.refreshDetail(source: id, range: range)
        async let series: Void = store.refreshSeries(source: id, range: range)
        _ = await (detail, series)
    }

    // MARK: 顶部

    private var headlineValue: Double? {
        displayed?.value ?? curve?.total ?? detail?.pnl
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                SourceIcon(id: id, size: 22)
                Text(detail?.label ?? range.caption)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.bottom, 10)

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
                }
                if let displayed, let curve {
                    Text("· " + displayed.date.crosshairText(span: curve.end.timeIntervalSince(curve.start)))
                        .foregroundStyle(.secondary)
                } else if let est = detail?.est {
                    Text("· 预估 \(store.money(est[0], signed: true)) ～ \(store.money(est[1], signed: true))")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .padding(.top, 7)

            if detail?.est != nil {
                HStack(spacing: 12) {
                    legend(AppTheme.estLow, "保守：离中间价近的分得多")
                    legend(AppTheme.estHigh, "乐观：按金额平分")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
            }
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(color).frame(width: 10, height: 2)
            Text(text)
        }
    }

    // MARK: 统计

    private func stats(_ detail: SourceDetail) -> some View {
        let fullDays = detail.days.dropFirst(detail.days.count > 1 ? 1 : 0)   // 今天没过完，多天时日均不算今天
        let average = fullDays.isEmpty ? nil : fullDays.map(\.pnl).reduce(0, +) / Double(fullDays.count)
        var items: [(String, String)] = [
            (detail.dailyOnly ? "记账天数" : "笔数", "\(detail.count)")
        ]
        if let win = detail.win { items.append(("胜率", win.percentText)) }
        if let average { items.append(("日均", store.money(average, signed: true))) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(items, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(item.1)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let foot = detail.foot, !foot.isEmpty {
                Text(foot)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 30)
    }

    // MARK: 分项

    private func partsSection(_ detail: SourceDetail) -> some View {
        let maxMagnitude = detail.parts.map { abs($0.pnl) }.max() ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader("分项")
            ForEach(Array(detail.parts.enumerated()), id: \.element.id) { index, part in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(part.name)
                            .font(.subheadline.weight(.medium))
                        Text([detail.dailyOnly ? nil : "\(part.count) \(SourceStyle.unit(for: id))", part.win.map { "胜率 " + $0.percentText }]
                            .compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(store.money(part.pnl, signed: true))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.tone(part.pnl))
                    }
                    .monospacedDigit()
                    ShareBar(value: part.pnl, maxMagnitude: maxMagnitude)
                }
                .padding(.vertical, 12)
                if index < detail.parts.count - 1 {
                    Hairline()
                }
            }
        }
    }

    // MARK: 每日

    private func daysSection(_ detail: SourceDetail) -> some View {
        let days = showAllDays ? detail.days : Array(detail.days.prefix(14))
        let maxMagnitude = detail.days.map { abs($0.pnl) }.max() ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader("每日") {
                if detail.days.count > 14 && !showAllDays {
                    Button("全部 \(detail.days.count) 天") { showAllDays = true }
                        .foregroundStyle(Color.accentColor)
                }
            }
            ForEach(days) { day in
                HStack(spacing: 12) {
                    Text(dayText(day.day))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 92, alignment: .leading)
                    ShareBar(value: day.pnl, maxMagnitude: maxMagnitude)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(store.money(day.pnl, signed: true))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.tone(day.pnl))
                        if let est = day.est {
                            Text("\(store.money(est[0], signed: true)) ～ \(store.money(est[1], signed: true))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(minWidth: 84, alignment: .trailing)
                }
                .monospacedDigit()
                .padding(.vertical, 9)
            }
        }
    }

    private func dayText(_ day: String) -> String {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return day }
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        return "\(parts[1])/\(parts[2]) " + date.formatted(.dateTime.weekday(.abbreviated))
    }

    // MARK: 记录

    private func recordsSection(_ detail: SourceDetail) -> some View {
        let records = Array(detail.records.prefix(recordLimit))
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader("记录")
            if records.isEmpty {
                Text("这段时间没有记录")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 12)
            }
            ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.title)
                            .font(.subheadline)
                            .lineLimit(2)
                        Text([record.ts.map { Date(timeIntervalSince1970: $0).feedText } ?? dayText(record.day), record.foot].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 8)
                    Text(store.money(record.pnl, signed: true))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.tone(record.pnl))
                }
                .monospacedDigit()
                .padding(.vertical, 10)
                if index < records.count - 1 {
                    Hairline()
                }
            }
            if detail.records.count > recordLimit {
                Button("再显示 \(min(50, detail.records.count - recordLimit)) 条") { recordLimit += 50 }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 14)
            }
        }
    }
}

// MARK: - 理财仓位

private struct PositionsSection: View {
    @Environment(Store.self) private var store
    let positions: [Position]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("仓位")
            ForEach(Array(positions.enumerated()), id: \.element.id) { index, position in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(position.name)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(store.money(position.value))
                            .font(.subheadline.weight(.semibold))
                    }
                    HStack {
                        metric("本金", store.money(position.principal))
                        metric("已记收益", store.money(position.got, signed: true))
                        metric("预计每天", store.money(position.dailyEst, signed: true))
                        metric("年化", position.apy.map { ($0 * 100).formatted(.number.precision(.fractionLength(1))) + "%" } ?? "—")
                    }
                    Text(position.note)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .monospacedDigit()
                .padding(.vertical, 12)
                if index < positions.count - 1 {
                    Hairline()
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.tertiary)
            Text(value).font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 订阅额度

private struct QuotaSection: View {
    @Environment(Store.self) private var store
    let quota: Quota

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("额度与月收入估算") {
                Text(Date(timeIntervalSince1970: quota.updated).feedText + " 更新")
                    .foregroundStyle(.tertiary)
            }
            ForEach(quota.groups) { group in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(group.name) × \(group.n)")
                            .font(.subheadline.weight(.medium))
                        Text((["打满 " + group.fill] + group.quota).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(group.net.map { store.money($0, signed: true) + "/月" } ?? "—")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.tone(group.net ?? 0))
                        if let each = group.netEach, group.n > 1 {
                            Text("单号 " + store.money(each, signed: true))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .monospacedDigit()
                .padding(.vertical, 10)
                Hairline()
            }
            HStack {
                Text("满额月净利合计")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(store.money(quota.net, signed: true) + "/月")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.tone(quota.net))
                    .monospacedDigit()
            }
            .padding(.vertical, 12)
        }
    }
}
