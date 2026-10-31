import SwiftUI

enum AppTheme {
    static let background = Color(red: 31 / 255, green: 31 / 255, blue: 29 / 255)
    static let negative = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let warning = Color(red: 1.0, green: 0.70, blue: 0.28)
    /// Ondo挂单两条预估线：蓝 = 保守，黄 = 乐观（沿用 TG /chart 的约定）
    static let estLow = Color(red: 0.42, green: 0.66, blue: 1.0)
    static let estHigh = Color(red: 1.0, green: 0.82, blue: 0.36)
    static let hairline = Color.white.opacity(0.07)

    /// 收益颜色：正数强调色，负数红，接近 0 灰
    static func tone(_ value: Double) -> Color {
        abs(value) < 0.005 ? .secondary : value > 0 ? .accentColor : negative
    }
}

/// 页面标题：大字直接浮在背景上
struct PageTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.largeTitle.weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 分组小标题，右侧可放一个次要按钮
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            trailing
                .font(.footnote.weight(.medium))
        }
        .padding(.top, 34)
        .padding(.bottom, 6)
    }
}

/// 来源图标：强调色淡底圆
struct SourceIcon: View {
    let id: String
    var size: CGFloat = 36
    var dimmed = false

    var body: some View {
        Image(systemName: SourceStyle.symbol(for: id))
            .font(.system(size: size * 0.39, weight: .semibold))
            .foregroundStyle(dimmed ? Color.secondary : Color.accentColor)
            .frame(width: size, height: size)
            .background((dimmed ? Color.white.opacity(0.06) : Color.accentColor.opacity(0.12)), in: Circle())
    }
}

/// 状态小点：取数失败红、程序久不更新橙
struct HealthDot: View {
    let health: SourceHealth

    var body: some View {
        if health != .ok {
            Circle()
                .fill(health == .error ? AppTheme.negative : AppTheme.warning)
                .frame(width: 6, height: 6)
                .accessibilityLabel(health == .error ? "取数失败" : "程序久未更新")
        }
    }
}

/// 细分隔线
struct Hairline: View {
    var leading: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(AppTheme.hairline)
            .frame(height: 0.5)
            .padding(.leading, leading)
    }
}

/// 横向比例条：正数强调色、负数红，长度按组内最大绝对值
struct ShareBar: View {
    let value: Double
    let maxMagnitude: Double

    var body: some View {
        GeometryReader { geometry in
            let ratio = maxMagnitude > 0 ? min(abs(value) / maxMagnitude, 1) : 0
            Capsule()
                .fill(AppTheme.tone(value).opacity(0.55))
                .frame(width: max(geometry.size.width * ratio, ratio > 0 ? 2 : 0), height: 3)
                .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 3)
    }
}

/// 页面统一外壳：深灰背景 + 可下拉刷新的滚动区域
struct PageScroll<Content: View>: View {
    var refresh: (() async -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .refreshable { await refresh?() }
        }
    }
}

extension Date {
    /// 动态列表里的时间：今天显示时分，昨天显示“昨天 时分”，更早显示月-日 时分
    var feedText: String {
        let calendar = Calendar.current
        let time = formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute())
        if calendar.isDateInToday(self) { return time }
        if calendar.isDateInYesterday(self) { return "昨天 " + time }
        return formatted(.dateTime.month(.defaultDigits).day()) + " " + time
    }
}

extension Double {
    var percentText: String {
        (self * 100).formatted(.number.precision(.fractionLength(0))) + "%"
    }
}
