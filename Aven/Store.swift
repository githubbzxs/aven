import Foundation
import Observation
import Security

/// 主币种：金额都按 U 记账（U 按 1:1 美元），人民币按 tg-hub 每小时取的实时汇率换算。
enum DisplayCurrency: String, CaseIterable, Identifiable {
    case usd
    case cny

    var id: Self { self }

    var title: String {
        switch self {
        case .usd: "美元"
        case .cny: "人民币"
        }
    }
}

enum APIError: LocalizedError {
    case notConfigured
    case unauthorized
    case server(Int, String?)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "还没有配置接口令牌"
        case .unauthorized: "接口令牌不对"
        case let .server(code, message): "服务器返回 \(code)" + (message.map { "：\($0)" } ?? "")
        }
    }
}

/// 全局数据：各接口结果按请求路径缓存在内存和磁盘里，冷启动先显示上次的数据再刷新。
@Observable
final class Store {
    static let defaultBase = "https://aven.0xpsyche.me"

    private(set) var overviews: [EarningsRange: Overview] = [:]
    private(set) var series: [String: Series] = [:]
    private(set) var details: [String: SourceDetail] = [:]
    private(set) var feed: [FeedItem] = []
    private(set) var lastUpdated: Date?
    private(set) var lastError: String?
    private(set) var isRefreshing = false

    var currency: DisplayCurrency {
        didSet { UserDefaults.standard.set(currency.rawValue, forKey: "currency") }
    }

    var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "baseURL") }
    }

    private(set) var token: String

    /// 视图读取时从磁盘补上的旧数据，不触发界面更新
    @ObservationIgnored private var diskSeries: [String: Series] = [:]
    @ObservationIgnored private var diskDetails: [String: SourceDetail] = [:]
    @ObservationIgnored private var curveMemo: [String: (series: Series, curve: CurveData)] = [:]

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let cacheDirectory: URL = {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("api", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    init() {
        currency = DisplayCurrency(rawValue: UserDefaults.standard.string(forKey: "currency") ?? "") ?? .usd
        baseURL = UserDefaults.standard.string(forKey: "baseURL") ?? Store.defaultBase
        token = Keychain.read() ?? (Bundle.main.object(forInfoDictionaryKey: "AvenAPIToken") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        lastUpdated = UserDefaults.standard.object(forKey: "lastUpdated") as? Date

        for range in EarningsRange.allCases {
            overviews[range] = cached(Overview.self, path: "/v1/overview", query: ["range": range.rawValue])
        }
        feed = cached(Feed.self, path: "/v1/feed", query: ["limit": "200"])?.items ?? []
    }

    var isConfigured: Bool { !token.isEmpty }

    /// 最近一次拿到的汇率（元/U）
    var rate: Double {
        overviews.values.max { $0.now < $1.now }?.rate ?? 0
    }

    func updateToken(_ value: String) {
        token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        Keychain.write(token)
    }

    // MARK: - 读取（先内存，再磁盘缓存）

    func seriesValue(source: String?, range: EarningsRange) -> Series? {
        let query = seriesQuery(source: source, range: range)
        let key = Self.key("/v1/series", query)
        if let value = series[key] ?? diskSeries[key] { return value }
        let value = cached(Series.self, path: "/v1/series", query: query)
        diskSeries[key] = value
        return value
    }

    func detailValue(source: String, range: EarningsRange) -> SourceDetail? {
        let query = ["src": source, "range": range.rawValue]
        let key = Self.key("/v1/source", query)
        if let value = details[key] ?? diskDetails[key] { return value }
        let value = cached(SourceDetail.self, path: "/v1/source", query: query)
        diskDetails[key] = value
        return value
    }

    /// 绘图数据：接口数据没变就复用上次算好的
    func curve(source: String?, range: EarningsRange) -> CurveData? {
        guard let value = seriesValue(source: source, range: range) else { return nil }
        let key = "\(source ?? "")|\(range.rawValue)"
        if let memo = curveMemo[key], memo.series.t1 == value.t1, memo.series.events.count == value.events.count {
            return memo.curve
        }
        let curve = CurveData(series: value)
        curveMemo[key] = (value, curve)
        return curve
    }

    /// 来源 id → 中文名
    var sourceNames: [String: String] {
        let sources = overviews[.day]?.sources ?? overviews.values.first?.sources ?? []
        return Dictionary(sources.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - 刷新

    func refreshOverview(_ range: EarningsRange) async {
        if let value: Overview = await fetch("/v1/overview", ["range": range.rawValue]) {
            overviews[range] = value
        }
    }

    func refreshSeries(source: String?, range: EarningsRange) async {
        let query = seriesQuery(source: source, range: range)
        if let value: Series = await fetch("/v1/series", query) {
            series[Self.key("/v1/series", query)] = value
        }
    }

    func refreshDetail(source: String, range: EarningsRange) async {
        let query = ["src": source, "range": range.rawValue]
        if let value: SourceDetail = await fetch("/v1/source", query) {
            details[Self.key("/v1/source", query)] = value
        }
    }

    func refreshFeed() async {
        if let value: Feed = await fetch("/v1/feed", ["limit": "200"]) {
            feed = value.items
        }
    }

    /// 首页和来源页用到的全部数据
    func refreshMain(range: EarningsRange) async {
        guard isConfigured else {
            lastError = APIError.notConfigured.localizedDescription
            return
        }
        isRefreshing = true
        async let first: Void = refreshOverview(range)
        async let today: Void = range == .day ? () : refreshOverview(.day)
        async let month: Void = range == .month ? () : refreshOverview(.month)
        async let curve: Void = refreshSeries(source: nil, range: range)
        async let activity: Void = refreshFeed()
        _ = await (first, today, month, curve, activity)
        isRefreshing = false
    }

    // MARK: - 网络

    private func fetch<T: Decodable>(_ path: String, _ query: [String: String]) async -> T? {
        do {
            let data = try await request(path, query)
            let value = try decoder.decode(T.self, from: data)
            try? data.write(to: cacheURL(path, query), options: .atomic)
            lastError = nil
            lastUpdated = .now
            UserDefaults.standard.set(lastUpdated, forKey: "lastUpdated")
            return value
        } catch is CancellationError {
            return nil
        } catch let error as URLError where error.code == .cancelled {
            return nil
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    private func request(_ path: String, _ query: [String: String]) async throws -> Data {
        guard isConfigured else { throw APIError.notConfigured }
        guard var components = URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines) + path) else {
            throw URLError(.badURL)
        }
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw APIError.unauthorized }
        guard code == 200 else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw APIError.server(code, message)
        }
        return data
    }

    /// 测试连接：返回往返毫秒数
    func ping() async throws -> Int {
        let start = Date.now
        _ = try await request("/v1/overview", ["range": "1d"])
        return Int(Date.now.timeIntervalSince(start) * 1000)
    }

    // MARK: - 缓存

    private func seriesQuery(source: String?, range: EarningsRange) -> [String: String] {
        var query = ["range": range.rawValue]
        if let source { query["src"] = source }
        return query
    }

    private static func key(_ path: String, _ query: [String: String]) -> String {
        path + "?" + query.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    }

    private func cacheURL(_ path: String, _ query: [String: String]) -> URL {
        let name = Self.key(path, query)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "&", with: "_")
        return cacheDirectory.appendingPathComponent(name + ".json")
    }

    private func cached<T: Decodable>(_ type: T.Type, path: String, query: [String: String]) -> T? {
        guard let data = try? Data(contentsOf: cacheURL(path, query)) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}

// MARK: - 金额格式

extension Store {
    /// 按主币种显示金额；signed 为 true 时正数带“+”
    func money(_ usd: Double, signed: Bool = false, currency: DisplayCurrency? = nil) -> String {
        let currency = currency ?? self.currency
        let value = currency == .cny ? usd * rate : usd
        let symbol = currency == .cny ? "¥" : "$"
        let digits = currency == .cny && abs(value) >= 1000 ? 0 : 2
        let magnitude = abs(value).formatted(.number.precision(.fractionLength(digits)))
        if abs(value) < 0.005 { return symbol + 0.0.formatted(.number.precision(.fractionLength(digits))) }
        if value < 0 { return "−" + symbol + magnitude }
        return (signed ? "+" : "") + symbol + magnitude
    }

    /// 另一种币种，用在大数字下面的小字
    func secondaryMoney(_ usd: Double) -> String {
        let other: DisplayCurrency = currency == .usd ? .cny : .usd
        if other == .cny && rate <= 0 { return "" }
        return "≈ " + money(usd, signed: true, currency: other)
    }
}

// MARK: - 钥匙串

enum Keychain {
    private static let service = "me.0xpsyche.aven"
    private static let account = "api-token"

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }
        return value
    }

    static func write(_ value: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty else { return }
        var item = base
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }
}
