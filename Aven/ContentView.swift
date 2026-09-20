import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case agent = "Agent"
    case sources = "Sources"

    var id: Self { self }
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
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab(value: AppTab.agent) {
                AgentView()
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab(value: AppTab.sources) {
                SourcesView()
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Spacer()
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(selection: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}

private struct BottomBar: View {
    @Binding var selection: AppTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    tabIcon(for: tab)
                        .foregroundStyle(iconColor(for: tab))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background {
                            if selection == tab {
                                Capsule()
                                    .fill(.black.opacity(0.5))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
                .accessibilityIdentifier("tab.\(tab.rawValue.lowercased())")
            }
        }
        .padding(4)
        .frame(maxWidth: 280)
        .glassEffect(.regular.tint(.white.opacity(0.04)), in: .capsule)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }

    @ViewBuilder
    private func tabIcon(for tab: AppTab) -> some View {
        switch tab {
        case .dashboard:
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 25, weight: .semibold))
        case .agent:
            Circle()
                .strokeBorder(lineWidth: 2.2)
                .frame(width: 28, height: 28)
        case .sources:
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 27, weight: .semibold))
        }
    }

    private func iconColor(for tab: AppTab) -> Color {
        if selection == tab {
            return .accentColor
        }
        return tab == .agent ? .white.opacity(0.45) : .white.opacity(0.95)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
