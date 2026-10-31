import Foundation

/// 时间范围，与 tg-hub 的 /pnl 同口径：1D 是今天 00:00（UTC+8）起，其余按自然日往回数。
enum EarningsRange: String, CaseIterable, Identifiable, Codable {
    case day = "1d"
    case week = "7d"
    case month = "30d"
    case all = "all"

    var id: Self { self }

    var title: String {
        switch self {
        case .day: "1D"
        case .week: "7D"
        case .month: "30D"
        case .all: "ALL"
        }
    }

    var caption: String {
        switch self {
        case .day: "今天"
        case .week: "近 7 天"
        case .month: "近 30 天"
        case .all: "累计"
        }
    }
}

struct Overview: Codable, Equatable {
    let now: Double
    let rate: Double
    let label: String
    let d0: String
    let d1: String
    let total: Double
    let today: Double
    let sources: [SourceSummary]
}

struct SourceSummary: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let pnl: Double
    let today: Double
    let count: Int
    let daily: Bool
    let retired: Bool
    let last: Double?
    let state: String
    let note: String?
    let est: [Double]?

    var health: SourceHealth { SourceHealth(rawValue: state) ?? .ok }
}

enum SourceHealth: String {
    case ok
    case stale
    case error
}

struct Series: Codable, Equatable {
    let t0: Double
    let t1: Double
    let label: String
    let events: [[Double]]
    let est: [[[Double]]]?
}

struct SourceDetail: Codable, Equatable {
    let id: String
    let name: String
    let label: String
    let pnl: Double
    let count: Int
    let dailyOnly: Bool
    let win: Double?
    let foot: String?
    let parts: [SourcePart]
    let days: [DayPnl]
    let rate: Double
    let state: String
    let note: String?
    let records: [SourceRecord]
    let est: [Double]?
    let positions: [Position]?
    let quota: Quota?

    var health: SourceHealth { SourceHealth(rawValue: state) ?? .ok }
}

struct SourcePart: Codable, Equatable, Identifiable {
    let name: String
    let count: Int
    let pnl: Double
    let win: Double?

    var id: String { name }
}

struct DayPnl: Codable, Equatable, Identifiable {
    let day: String
    let pnl: Double
    let est: [Double]?

    var id: String { day }
}

struct SourceRecord: Codable, Equatable {
    let ts: Double?
    let day: String
    let pnl: Double
    let title: String
    let sub: String?
    let foot: String?
}

struct Position: Codable, Equatable, Identifiable {
    let name: String
    let principal: Double
    let value: Double
    let dailyEst: Double
    let apy: Double?
    let note: String
    let got: Double

    var id: String { name }
}

struct Quota: Codable, Equatable {
    let updated: Double
    let groups: [QuotaGroup]
    let net: Double
}

struct QuotaGroup: Codable, Equatable, Identifiable {
    let name: String
    let n: Int
    let fill: String
    let quota: [String]
    let net: Double?
    let netEach: Double?

    var id: String { name }
}

struct FeedItem: Codable, Equatable {
    let ts: Double
    let kind: String
    let src: String?
    let title: String
    let body: String?
    let pnl: Double?
}

struct Feed: Codable, Equatable {
    let items: [FeedItem]
}

/// 来源的固定外观：图标按策略性质挑，颜色统一用强调色。
enum SourceStyle {
    static func symbol(for id: String) -> String {
        switch id {
        case "ai": "cpu"
        case "cdr": "drop.fill"
        case "pf": "timer"
        case "weather": "cloud.sun.fill"
        case "rfc": "arrow.triangle.2.circlepath"
        case "letf": "arrow.left.arrow.right"
        case "clm": "square.on.square"
        case "olp": "list.bullet.indent"
        case "lc": "building.columns.fill"
        default: "circle.grid.2x2.fill"
        }
    }

    /// 单位：逐笔来源按“单”，出租AI订阅和理财是按天记账
    static func unit(for id: String) -> String {
        switch id {
        case "ai", "lc": "天"
        case "weather": "仓"
        case "olp": "轮"
        default: "笔"
        }
    }
}
