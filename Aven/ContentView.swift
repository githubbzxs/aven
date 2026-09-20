import SwiftUI

enum AppTab: String {
    case dashboard = "Dashboard"
    case agent = "Agent"
    case sources = "Sources"
}

enum AppTheme {
    static let background = Color(red: 31 / 255, green: 31 / 255, blue: 29 / 255)
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: AppTab.dashboard) {
                DashboardView()
            } label: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .accessibilityLabel(AppTab.dashboard.rawValue)
            }

            Tab(value: AppTab.agent) {
                AgentView()
            } label: {
                Image("AgentTabIcon")
                    .accessibilityLabel(AppTab.agent.rawValue)
            }

            Tab(value: AppTab.sources) {
                SourcesView()
            } label: {
                Image(systemName: "square.3.layers.3d")
                    .accessibilityLabel(AppTab.sources.rawValue)
            }
        }
        .tabViewStyle(.tabBarOnly)
        .tabBarMinimizeBehavior(.never)
        .tint(.accentColor)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Image("Avatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .padding(4)
                    .glassEffect(.regular, in: .circle)
                    .accessibilityHidden(true)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
