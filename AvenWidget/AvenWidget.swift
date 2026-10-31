import AppIntents
import SwiftUI
import WidgetKit

// 主屏与锁屏小组件：今日收益、近 7 天收益和今日贡献最大的几个来源。
// 小组件自己请求 /v1/overview?range=7d，令牌由构建时注入 Info.plist（与 App 同一个 AVEN_API_TOKEN）。

private enum Palette {
    static let accent = Color(red: 0.651, green: 0.435, blue: 0.941)
    static let negative = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let background = Color(red: 31 / 255, green: 31 / 255, blue: 29 / 255)

    static func tone(_ value: Double) -> Color {
        abs(value) < 0.005 ? .secondary : value > 0 ? accent : negative
    }
}

// MARK: - 数据

struct WidgetOverview: Decodable {
    struct Source: Decodable {
        let id: String
        let name: String
        let today: Double
        let retired: Bool
        let state: String
    }

    let now: Double
    let total: Double
    let today: Double
    let sources: [Source]

    /// 今日有收益的在跑来源，按绝对值从大到小
    var movers: [Source] {
        sources.filter { !$0.retired && abs($0.today) >= 0.005 }
            .sorted { abs($0.today) > abs($1.today) }
    }

    var hasError: Bool {
        sources.contains { !$0.retired && $0.state == "error" }
    }
}

struct AvenEntry: TimelineEntry {
    let date: Date
    let overview: WidgetOverview?
    let failure: String?

    static let placeholder = AvenEntry(
        date: .now,
        overview: WidgetOverview(now: Date.now.timeIntervalSince1970, total: 86.4, today: 12.35, sources: [
            .init(id: "lc", name: "理财", today: 6.1, retired: false, state: "ok"),
            .init(id: "ai", name: "订阅出租", today: 4.2, retired: false, state: "ok"),
            .init(id: "rfc", name: "RFC", today: 2.05, retired: false, state: "ok")
        ]),
        failure: nil
    )
}

private func fetchOverview() async throws -> WidgetOverview {
    let token = Bundle.main.object(forInfoDictionaryKey: "AvenAPIToken") as? String ?? ""
    guard !token.isEmpty else { throw URLError(.userAuthenticationRequired) }
    var request = URLRequest(url: URL(string: "https://aven.0xpsyche.me/v1/overview?range=7d")!)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 15
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(WidgetOverview.self, from: data)
}

struct AvenWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Aven 收益"
}

struct AvenProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> AvenEntry { .placeholder }

    func snapshot(for configuration: AvenWidgetIntent, in context: Context) async -> AvenEntry {
        if context.isPreview { return .placeholder }
        return await load()
    }

    func timeline(for configuration: AvenWidgetIntent, in context: Context) async -> Timeline<AvenEntry> {
        let entry = await load()
        // 正常 20 分钟刷一次；失败 5 分钟后重试
        let next = Date.now.addingTimeInterval(entry.overview == nil ? 300 : 1200)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func load() async -> AvenEntry {
        do {
            return AvenEntry(date: .now, overview: try await fetchOverview(), failure: nil)
        } catch let error as URLError where error.code == .userAuthenticationRequired {
            return AvenEntry(date: .now, overview: nil, failure: "未注入令牌")
        } catch {
            return AvenEntry(date: .now, overview: nil, failure: "暂时连不上")
        }
    }
}

// MARK: - 金额

private func usd(_ value: Double, signed: Bool = true) -> String {
    let magnitude = abs(value).formatted(.number.precision(.fractionLength(2)))
    if abs(value) < 0.005 { return "$0.00" }
    if value < 0 { return "−$" + magnitude }
    return (signed ? "+$" : "$") + magnitude
}

// MARK: - 视图

struct AvenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AvenEntry

    var body: some View {
        Group {
            if let overview = entry.overview {
                switch family {
                case .accessoryInline: inline(overview)
                case .accessoryRectangular: rectangular(overview)
                case .systemMedium: medium(overview)
                default: small(overview)
                }
            } else {
                failure
            }
        }
        .widgetURL(URL(string: "aven://dashboard"))
        .containerBackground(for: .widget) { Palette.background }
    }

    private var failure: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Aven").font(.caption.weight(.semibold))
            Text(entry.failure ?? "暂无数据")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(_ overview: WidgetOverview) -> some View {
        HStack(spacing: 5) {
            Text("今日")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            if overview.hasError {
                Circle().fill(Palette.negative).frame(width: 6, height: 6)
            }
            Spacer(minLength: 0)
            Text(Date(timeIntervalSince1970: overview.now), style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func today(_ overview: WidgetOverview, size: CGFloat) -> some View {
        Text(usd(overview.today))
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Palette.tone(overview.today))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }

    private func week(_ overview: WidgetOverview) -> some View {
        HStack(spacing: 4) {
            Text("7D").foregroundStyle(.secondary)
            Text(usd(overview.total)).foregroundStyle(Palette.tone(overview.total))
        }
        .font(.caption.weight(.medium))
        .monospacedDigit()
    }

    private func small(_ overview: WidgetOverview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header(overview)
            Spacer(minLength: 0)
            today(overview, size: 30)
            week(overview)
        }
    }

    private func medium(_ overview: WidgetOverview) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                header(overview)
                Spacer(minLength: 0)
                today(overview, size: 32)
                week(overview)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                let movers = overview.movers.prefix(4)
                if movers.isEmpty {
                    Text("今天还没有收益")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(movers), id: \.id) { source in
                        Link(destination: URL(string: "aven://source/\(source.id)")!) {
                            HStack {
                                Text(source.name)
                                    .lineLimit(1)
                                    .foregroundStyle(source.state == "error" ? Palette.negative : .primary)
                                Spacer(minLength: 6)
                                Text(usd(source.today))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.tone(source.today))
                            }
                            .font(.caption)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rectangular(_ overview: WidgetOverview) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(overview.hasError ? "Aven 今日 · 有异常" : "Aven 今日")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(usd(overview.today))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .widgetAccentable()
            Text("7D " + usd(overview.total))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inline(_ overview: WidgetOverview) -> some View {
        Text("Aven 今日 \(usd(overview.today))")
    }
}

@main
struct AvenWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AvenEarnings", intent: AvenWidgetIntent.self, provider: AvenProvider()) { entry in
            AvenWidgetView(entry: entry)
        }
        .configurationDisplayName("Aven 收益")
        .description("今日与近 7 天的被动收入")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}
