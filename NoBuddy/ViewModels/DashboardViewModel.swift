import Foundation
import Combine
import SwiftUI

/// ViewModel for the dashboard view
@MainActor
class DashboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var recentActivity: [DashboardActivity] = []
    @Published var workspaceStats: [WorkspaceStats] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    /// Load dashboard data including recent activity and workspace statistics
    func loadDashboardData(tokens: [SafeNotionToken], tokenManager: SecureTokenManager) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load recent activity from various sources
            await loadRecentActivity(tokens: tokens, tokenManager: tokenManager)
            
            // Load workspace statistics
            await loadWorkspaceStats(tokens: tokens, tokenManager: tokenManager)
        } catch {
            errorMessage = "Failed to load dashboard data: \(error.localizedDescription)"
        }
    }
    
    /// Refresh all dashboard data
    func refresh(tokens: [SafeNotionToken], tokenManager: SecureTokenManager) async {
        await loadDashboardData(tokens: tokens, tokenManager: tokenManager)
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func loadRecentActivity(tokens: [SafeNotionToken], tokenManager: SecureTokenManager) async {
        var activities: [DashboardActivity] = []
        
        // For each valid token, get recent activity
        for token in tokens.filter({ $0.isValid }) {
            do {
                let tokenValue = try tokenManager.getToken(token.id)
                let apiClient = NotionAPIClient()
                
                // Search for recently modified pages
                let searchResult = try await apiClient.search(
                    sort: ["direction": "descending", "timestamp": "last_edited_time"],
                    pageSize: 10,
                    token: tokenValue
                )
                
                // Convert search results to activities
                for result in searchResult.results.prefix(5) {
                    let activity = createActivity(from: result, workspace: token.workspaceName ?? token.name)
                    activities.append(activity)
                }
            } catch {
                // Log error but continue with other tokens
                print("Failed to load activity for token \(token.name): \(error)")
            }
        }
        
        // Sort by timestamp and take the most recent
        recentActivity = Array(activities.sorted { $0.timestamp > $1.timestamp }.prefix(10))
        
        // If no real data available, show mock data for demo
        if recentActivity.isEmpty && !tokens.isEmpty {
            recentActivity = generateMockActivity()
        }
    }
    
    private func loadWorkspaceStats(tokens: [SafeNotionToken], tokenManager: SecureTokenManager) async {
        var stats: [WorkspaceStats] = []
        
        for token in tokens.filter({ $0.isValid }) {
            do {
                let tokenValue = try tokenManager.getToken(token.id)
                let apiClient = NotionAPIClient()
                
                // Get workspace information and basic stats
                let user = try await apiClient.getCurrentUser(token: tokenValue)
                
                // Search for databases and pages to get counts
                let searchResult = try await apiClient.search(token: tokenValue)
                
                let databaseCount = searchResult.results.compactMap { result in
                    if case .database = result { return 1 } else { return nil }
                }.count
                
                let pageCount = searchResult.results.compactMap { result in
                    if case .page = result { return 1 } else { return nil }
                }.count
                
                let workspaceStats = WorkspaceStats(
                    tokenId: token.id,
                    workspaceName: token.workspaceName ?? token.name,
                    databaseCount: databaseCount,
                    pageCount: pageCount,
                    lastSync: Date()
                )
                
                stats.append(workspaceStats)
            } catch {
                print("Failed to load stats for token \(token.name): \(error)")
            }
        }
        
        workspaceStats = stats
    }
    
    private func createActivity(from searchResult: SearchResult, workspace: String) -> DashboardActivity {
        switch searchResult {
        case .page(let page):
            return DashboardActivity(
                id: UUID(),
                title: extractTitle(from: page.properties),
                description: "Page updated in \(workspace)",
                icon: "doc.text",
                color: .blue,
                timestamp: page.lastEditedTime
            )
        case .database(let database):
            return DashboardActivity(
                id: UUID(),
                title: database.title.first?.plainText ?? "Untitled Database",
                description: "Database updated in \(workspace)",
                icon: "square.grid.2x2",
                color: .purple,
                timestamp: database.lastEditedTime
            )
        }
    }
    
    private func extractTitle(from properties: [String: PageProperty]) -> String {
        // Look for title property
        for (_, property) in properties {
            if case .title(let richTexts) = property {
                return richTexts.first?.plainText ?? "Untitled"
            }
        }
        return "Untitled"
    }
    
    private func generateMockActivity() -> [DashboardActivity] {
        [
            DashboardActivity(
                id: UUID(),
                title: "Project Planning Database",
                description: "3 new tasks added",
                icon: "checkmark.circle",
                color: .green,
                timestamp: Date().addingTimeInterval(-300)
            ),
            DashboardActivity(
                id: UUID(),
                title: "Meeting Notes - Sprint Review",
                description: "Page created and shared",
                icon: "doc.text",
                color: .blue,
                timestamp: Date().addingTimeInterval(-1800)
            ),
            DashboardActivity(
                id: UUID(),
                title: "Knowledge Base",
                description: "Database structure updated",
                icon: "square.grid.2x2",
                color: .purple,
                timestamp: Date().addingTimeInterval(-3600)
            ),
            DashboardActivity(
                id: UUID(),
                title: "Weekly Goals",
                description: "2 items marked complete",
                icon: "target",
                color: .orange,
                timestamp: Date().addingTimeInterval(-7200)
            )
        ]
    }
}

// MARK: - Supporting Models

struct DashboardActivity: Identifiable {
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

struct WorkspaceStats: Identifiable {
    let id = UUID()
    let tokenId: UUID
    let workspaceName: String
    let databaseCount: Int
    let pageCount: Int
    let lastSync: Date
    
    var totalItems: Int {
        databaseCount + pageCount
    }
}