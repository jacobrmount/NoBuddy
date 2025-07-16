import SwiftUI

struct DashboardView: View {
    
    // MARK: - Environment Objects
    @EnvironmentObject var tokenManager: SecureTokenManager
    @EnvironmentObject var dataManager: DataManager
    
    // MARK: - State
    @State private var isLoading = false
    @State private var showingTokenManagement = false
    @State private var recentDatabases: [CachedDatabase] = []
    @State private var recentPages: [CachedPage] = []
    @State private var dashboardStats = DashboardStats()
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header Section
                    HeaderSection()
                    
                    // Quick Stats
                    StatsSection(stats: dashboardStats)
                    
                    // Connected Workspaces
                    WorkspacesSection()
                    
                    // Recent Activity
                    RecentActivitySection(
                        databases: recentDatabases,
                        pages: recentPages
                    )
                    
                    // Quick Actions
                    QuickActionsSection()
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await refreshDashboard()
            }
            .onAppear {
                loadDashboardData()
            }
            .sheet(isPresented: $showingTokenManagement) {
                TokenManagementView()
            }
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private func HeaderSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to NoBuddy")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Your Notion companion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showingTokenManagement = true
                }) {
                    Image(systemName: "key.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            if tokenManager.tokens.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    Text("No tokens configured")
                        .font(.headline)
                    
                    Text("Add a Notion integration token to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Add Token") {
                        showingTokenManagement = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Stats Section
    
    @ViewBuilder
    private func StatsSection(stats: DashboardStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "Databases",
                    value: "\(stats.databaseCount)",
                    icon: "tablecells",
                    color: .blue
                )
                
                StatCard(
                    title: "Pages",
                    value: "\(stats.pageCount)",
                    icon: "doc.text",
                    color: .green
                )
                
                StatCard(
                    title: "Tokens",
                    value: "\(stats.tokenCount)",
                    icon: "key",
                    color: .purple
                )
                
                StatCard(
                    title: "Last Sync",
                    value: stats.lastSyncText,
                    icon: "arrow.clockwise",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - Workspaces Section
    
    @ViewBuilder
    private func WorkspacesSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Connected Workspaces")
                    .font(.headline)
                
                Spacer()
                
                if !tokenManager.tokens.isEmpty {
                    Button("Validate All") {
                        Task {
                            await tokenManager.validateAllTokens()
                            updateStats()
                        }
                    }
                    .font(.caption)
                    .disabled(tokenManager.isLoading)
                }
            }
            
            if tokenManager.tokens.isEmpty {
                ContentUnavailableView(
                    "No Workspaces",
                    systemImage: "building.2",
                    description: Text("Add a token to connect to your Notion workspace")
                )
                .frame(height: 120)
            } else {
                ForEach(tokenManager.tokens) { token in
                    WorkspaceCard(token: token)
                }
            }
        }
    }
    
    // MARK: - Recent Activity Section
    
    @ViewBuilder
    private func RecentActivitySection(databases: [CachedDatabase], pages: [CachedPage]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            
            if databases.isEmpty && pages.isEmpty {
                ContentUnavailableView(
                    "No Recent Activity",
                    systemImage: "clock",
                    description: Text("Your recent databases and pages will appear here")
                )
                .frame(height: 120)
            } else {
                VStack(spacing: 8) {
                    if !databases.isEmpty {
                        Text("Recent Databases")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ForEach(databases.prefix(3), id: \.objectID) { database in
                            RecentDatabaseRow(database: database)
                        }
                    }
                    
                    if !pages.isEmpty {
                        Text("Recent Pages")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                        
                        ForEach(pages.prefix(5), id: \.objectID) { page in
                            RecentPageRow(page: page)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Actions Section
    
    @ViewBuilder
    private func QuickActionsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickActionButton(
                    title: "Create Page",
                    icon: "doc.badge.plus",
                    color: .blue
                ) {
                    // TODO: Implement create page
                }
                
                QuickActionButton(
                    title: "Search",
                    icon: "magnifyingglass",
                    color: .purple
                ) {
                    // TODO: Navigate to search
                }
                
                QuickActionButton(
                    title: "Add Widget",
                    icon: "square.grid.2x2",
                    color: .green
                ) {
                    // TODO: Implement widget configuration
                }
                
                QuickActionButton(
                    title: "Settings",
                    icon: "gearshape",
                    color: .gray
                ) {
                    // TODO: Navigate to settings
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadDashboardData() {
        guard !tokenManager.tokens.isEmpty else { return }
        
        // Load cached data
        for token in tokenManager.tokens {
            let databases = dataManager.fetchCachedDatabases(for: token.id)
            let pages = dataManager.fetchCachedPages(for: token.id)
            
            recentDatabases.append(contentsOf: databases)
            recentPages.append(contentsOf: pages)
        }
        
        // Sort by last cached date
        recentDatabases.sort { ($0.lastCached ?? Date.distantPast) > ($1.lastCached ?? Date.distantPast) }
        recentPages.sort { ($0.lastCached ?? Date.distantPast) > ($1.lastCached ?? Date.distantPast) }
        
        updateStats()
    }
    
    private func refreshDashboard() async {
        isLoading = true
        defer { isLoading = false }
        
        // Refresh token validation
        await tokenManager.validateAllTokens()
        
        // TODO: Refresh data from API
        
        updateStats()
    }
    
    private func updateStats() {
        dashboardStats = DashboardStats(
            databaseCount: recentDatabases.count,
            pageCount: recentPages.count,
            tokenCount: tokenManager.tokens.count,
            lastSync: recentDatabases.first?.lastCached ?? recentPages.first?.lastCached
        )
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WorkspaceCard: View {
    let token: NotionToken
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(token.displayName)
                    .font(.headline)
                
                Text(token.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                ValidationStatusBadge(token: token)
                
                if let lastValidated = token.lastValidated {
                    Text(lastValidated, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RecentDatabaseRow: View {
    let database: CachedDatabase
    
    var body: some View {
        HStack {
            Image(systemName: "tablecells")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(database.title ?? "Untitled Database")
                    .font(.subheadline)
                    .lineLimit(1)
                
                if let lastCached = database.lastCached {
                    Text("Updated \(lastCached, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                if let url = database.url, let nsURL = URL(string: url) {
                    UIApplication.shared.open(nsURL)
                }
            }) {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RecentPageRow: View {
    let page: CachedPage
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(page.title ?? "Untitled Page")
                    .font(.subheadline)
                    .lineLimit(1)
                
                if let lastCached = page.lastCached {
                    Text("Updated \(lastCached, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                if let url = page.url, let nsURL = URL(string: url) {
                    UIApplication.shared.open(nsURL)
                }
            }) {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Data Models

struct DashboardStats {
    let databaseCount: Int
    let pageCount: Int
    let tokenCount: Int
    let lastSync: Date?
    
    init(databaseCount: Int = 0, pageCount: Int = 0, tokenCount: Int = 0, lastSync: Date? = nil) {
        self.databaseCount = databaseCount
        self.pageCount = pageCount
        self.tokenCount = tokenCount
        self.lastSync = lastSync
    }
    
    var lastSyncText: String {
        guard let lastSync = lastSync else { return "Never" }
        return lastSync.formatted(.relative(presentation: .numeric))
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(SecureTokenManager())
        .environmentObject(DataManager())
}