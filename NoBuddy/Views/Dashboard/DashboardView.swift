import SwiftUI

/// Dashboard view showing workspace overview and recent activity
struct DashboardView: View {
    @EnvironmentObject var tokenManager: SecureTokenManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background with glass morphism effect
                backgroundView
                
                if tokenManager.tokens.isEmpty {
                    emptyStateView
                } else {
                    dashboardContent
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .refreshable {
                await refreshData()
            }
        }
    }
    
    // MARK: - Background View
    
    private var backgroundView: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.black, Color(white: 0.05)]
                        : [Color(white: 0.98), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .ignoresSafeArea()
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Dashboard icon with glass effect
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                Image(systemName: "rectangle.grid.2x2.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("No workspaces connected")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Add your first Notion token to see your workspace data here")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Dashboard Content
    
    private var dashboardContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Workspace overview section
                workspaceOverviewSection
                
                // Quick stats section
                quickStatsSection
                
                // Recent activity section (placeholder)
                recentActivitySection
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Workspace Overview Section
    
    private var workspaceOverviewSection: some View {
        VStack(spacing: 16) {
            sectionHeader("Workspaces", subtitle: "\(tokenManager.tokens.count) connected")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(tokenManager.tokens) { token in
                    WorkspaceCard(token: token)
                }
            }
        }
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        VStack(spacing: 16) {
            sectionHeader("Quick Stats", subtitle: "Overview of your data")
            
            HStack(spacing: 12) {
                StatCard(
                    title: "Valid Tokens",
                    value: "\(tokenManager.tokens.filter(\.isValid).count)",
                    icon: "checkmark.shield.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Total Tokens",
                    value: "\(tokenManager.tokens.count)",
                    icon: "key.fill",
                    color: .blue
                )
            }
        }
    }
    
    // MARK: - Recent Activity Section
    
    private var recentActivitySection: some View {
        VStack(spacing: 16) {
            sectionHeader("Recent Activity", subtitle: "Latest updates")
            
            VStack(spacing: 12) {
                ForEach(recentActivities, id: \.id) { activity in
                    ActivityCard(activity: activity)
                }
            }
        }
    }
    
    // MARK: - Refresh Button
    
    private var refreshButton: some View {
        Button(action: { Task { await refreshData() } }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                if isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
        .disabled(isRefreshing)
        .buttonStyle(NoBuddyScaleButtonStyle()) // ← Fixed this line
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func refreshData() async {
        isRefreshing = true
        
        // Refresh token data
        await tokenManager.loadTokens()
        
        // Add a small delay for visual feedback
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        isRefreshing = false
    }
    
    // MARK: - Sample Data
    
    private var recentActivities: [ActivityItem] {
        [
            ActivityItem(
                id: UUID(),
                title: "Token validated successfully",
                description: "My Workspace token was validated",
                timestamp: Date().addingTimeInterval(-300),
                type: .validation
            ),
            ActivityItem(
                id: UUID(),
                title: "New token added",
                description: "Personal Workspace token was added",
                timestamp: Date().addingTimeInterval(-3600),
                type: .addition
            )
        ]
    }
}

// MARK: - Workspace Card

struct WorkspaceCard: View {
    let token: NotionToken
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: token.isValid
                                    ? [.green.opacity(0.7), .blue.opacity(0.7)]
                                    : [.gray.opacity(0.5), .gray.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "building.2")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(token.isValid ? .green : .red)
                    .frame(width: 8, height: 8)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(token.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(token.isValid ? "Connected" : "Connection Failed")
                    .font(.caption)
                    .foregroundColor(token.isValid ? .green : .red)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .frame(height: 100)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
            }
            
            // Content
            VStack(spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Activity Card

struct ActivityCard: View {
    let activity: ActivityItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(activity.type.color.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: activity.type.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(activity.type.color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(activity.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Timestamp
            Text(formatRelativeTime(activity.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Types

struct ActivityItem {
    let id: UUID
    let title: String
    let description: String
    let timestamp: Date
    let type: ActivityType
}

enum ActivityType {
    case validation
    case addition
    case deletion
    case error
    
    var icon: String {
        switch self {
        case .validation: return "checkmark.circle.fill"
        case .addition: return "plus.circle.fill"
        case .deletion: return "minus.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .validation: return .green
        case .addition: return .blue
        case .deletion: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Preview

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(SecureTokenManager())
            .preferredColorScheme(.light)
        
        DashboardView()
            .environmentObject(SecureTokenManager())
            .preferredColorScheme(.dark)
    }
} 
