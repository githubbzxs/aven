import SwiftUI

struct DashboardView: View {
    var body: some View {
        AppTheme.background
            .ignoresSafeArea()
            .accessibilityIdentifier("screen.dashboard")
    }
}

struct AgentView: View {
    var body: some View {
        AppTheme.background
            .ignoresSafeArea()
            .accessibilityIdentifier("screen.agent")
    }
}

struct SourcesView: View {
    var body: some View {
        AppTheme.background
            .ignoresSafeArea()
            .accessibilityIdentifier("screen.sources")
    }
}
