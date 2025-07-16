import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var tokenManager: SecureTokenManager
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    if tokenManager.tokens.isEmpty {
                        EmptyDashboardView()
                    } else {
                        workspacesSection
                        
                        if !viewModel.recentActivity.isEmpty {
                            recentActivitySection
                        }
                        
                        quickActionsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await viewModel.loadDashboardData(tokens: tokenManager.tokens, tokenManager: tokenManager)
            }
            .onAppear {
                Task {
                    await viewModel.loadDashboardData(tokens: tokenManager.tokens, tokenManager: tokenManager)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private var workspacesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Workspaces")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(tokenManager.tokens.filter { $0.isValid }) { token in
                    WorkspaceCard(token: token)
                }
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.recentActivity.prefix(5), id: \.id) { activity in
                    RecentActivityRow(activity: activity)
                }
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionCard(
                    title: "Create Page",
                    icon: "doc.badge.plus",
                    color: .blue
                ) {
                    // TODO: Implement create page action
                }
                
                QuickActionCard(
                    title: "Search",
                    icon: "magnifyingglass",
                    color: .green
                ) {
                    // TODO: Implement search action
                }
                
                QuickActionCard(
                    title: "Add Widget",
                    icon: "plus.app",
                    color: .purple
                ) {
                    // TODO: Implement add widget action
                }
                
                QuickActionCard(
                    title: "Settings",
                    icon: "gear",
                    color: .gray
                ) {
                    // TODO: Navigate to settings
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct EmptyDashboardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "house")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Welcome to NoBuddy")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Connect your Notion workspace to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Add Token") {
                // This will be handled by the parent tab view
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct WorkspaceCard: View {
    let token: SafeNotionToken
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(token.isValid ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(token.workspaceName ?? token.name)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(token.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct RecentActivityRow: View {
    let activity: DashboardActivity
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .font(.system(size: 16))
                .foregroundColor(activity.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(activity.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(activity.timeAgo)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ViewModel

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var recentActivity: [DashboardActivity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadDashboardData(tokens: [SafeNotionToken], tokenManager: SecureTokenManager) async {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate loading recent activity
        // In a real app, this would fetch from Core Data or the API
        recentActivity = generateMockActivity()
        
        // TODO: Load real data from Notion API
        // - Recent pages modified
        // - Recent database entries
        // - Widget performance data
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    private func generateMockActivity() -> [DashboardActivity] {
        [
            DashboardActivity(
                id: UUID(),
                title: "Task Database Updated",
                description: "3 new entries added",
                icon: "checkmark.circle",
                color: .green,
                timestamp: Date().addingTimeInterval(-300)
            ),
            DashboardActivity(
                id: UUID(),
                title: "Meeting Notes Created",
                description: "Daily standup notes",
                icon: "doc.text",
                color: .blue,
                timestamp: Date().addingTimeInterval(-1800)
            ),
            DashboardActivity(
                id: UUID(),
                title: "Project Database Queried",
                description: "Via widget update",
                icon: "square.grid.2x2",
                color: .purple,
                timestamp: Date().addingTimeInterval(-3600)
            )
        ]
    }
}

// MARK: - Models

struct DashboardActivity {
    let id: UUID
    let title: String
    let description: String
    let icon: String
    let color: Color
    let timestamp: Date
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

#Preview {
    DashboardView()
        .environmentObject(SecureTokenManager())
        .environmentObject(DataManager())
}