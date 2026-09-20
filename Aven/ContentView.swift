import SwiftUI

enum AppTab: String {
    case sources = "Sources"
    case dashboard = "Dashboard"
    case settings = "Settings"
}

enum AppTheme {
    static let background = Color(red: 31 / 255, green: 31 / 255, blue: 29 / 255)
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: AppTab.sources) {
                SourcesView()
            } label: {
                Image(systemName: "square.3.layers.3d")
                    .accessibilityLabel(AppTab.sources.rawValue)
            }

            Tab(value: AppTab.dashboard) {
                DashboardView()
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
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
