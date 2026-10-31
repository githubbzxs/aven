import SwiftUI

enum AppTab: String {
    case sources = "Sources"
    case dashboard = "Dashboard"
    case settings = "Settings"
}

enum Route: Hashable {
    case source(String)
    case feed
}

struct ContentView: View {
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .dashboard
    @State private var dashboardPath: [Route] = []
    @State private var sourcesPath: [Route] = []
    @AppStorage("dashboardRange") private var dashboardRange: EarningsRange = .day

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: AppTab.sources) {
                NavigationStack(path: $sourcesPath) {
                    SourcesView()
                        .navigationDestination(for: Route.self, destination: destination)
                }
            } label: {
                Image(systemName: "square.3.layers.3d")
                    .accessibilityLabel(AppTab.sources.rawValue)
            }

            Tab(value: AppTab.dashboard) {
                NavigationStack(path: $dashboardPath) {
                    DashboardView(range: $dashboardRange)
                        .navigationDestination(for: Route.self, destination: destination)
                }
            } label: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .accessibilityLabel(AppTab.dashboard.rawValue)
            }

            Tab(value: AppTab.settings) {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .accessibilityLabel(AppTab.settings.rawValue)
            }
        }
        .tabViewStyle(.tabBarOnly)
        .tabBarMinimizeBehavior(.never)
        .tint(.accentColor)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: selectedTab)
        .background(AppTheme.background.ignoresSafeArea())
        // 前台时每 30 秒刷新一次首页和来源页的数据
        .task(id: "\(scenePhase == .active)-\(dashboardRange.rawValue)") {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await store.refreshMain(range: dashboardRange)
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .onOpenURL(perform: open)
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case let .source(id): SourceDetailView(id: id)
        case .feed: FeedView()
        }
    }

    /// Bark 通知点开后的跳转：aven://source/<来源 id>、aven://dashboard
    private func open(_ url: URL) {
        guard url.scheme == "aven" else { return }
        switch url.host() {
        case "source":
            let id = url.pathComponents.dropFirst().first ?? ""
            guard !id.isEmpty else { return }
            selectedTab = .sources
            sourcesPath = [.source(id)]
        case "feed":
            selectedTab = .dashboard
            dashboardPath = [.feed]
        default:
            selectedTab = .dashboard
            dashboardPath = []
        }
    }
}
