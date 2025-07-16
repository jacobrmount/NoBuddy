import SwiftUI

struct ContentView: View {
    
    // MARK: - Environment Objects
    @EnvironmentObject var tokenManager: SecureTokenManager
    @EnvironmentObject var dataManager: DataManager
    
    // MARK: - State
    @State private var selectedTab = 0
    @State private var showingTokenSetup = false
    
    var body: some View {
        Group {
            if tokenManager.tokens.isEmpty && !tokenManager.isLoading {
                // Show onboarding when no tokens are configured
                OnboardingView()
            } else {
                // Main app interface
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Dashboard")
                        }
                        .tag(0)
                    
                    SearchView()
                        .tabItem {
                            Image(systemName: "magnifyingglass")
                            Text("Search")
                        }
                        .tag(1)
                    
                    QuickActionsView()
                        .tabItem {
                            Image(systemName: "plus.circle.fill")
                            Text("Quick Actions")
                        }
                        .tag(2)
                    
                    SettingsView()
                        .tabItem {
                            Image(systemName: "gearshape.fill")
                            Text("Settings")
                        }
                        .tag(3)
                }
                .accentColor(.blue)
            }
        }
        .onAppear {
            checkTokenStatus()
        }
        .sheet(isPresented: $showingTokenSetup) {
            NavigationView {
                TokenManagementView()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkTokenStatus() {
        // Check if we need to show token setup
        if tokenManager.tokens.isEmpty {
            showingTokenSetup = true
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @EnvironmentObject var tokenManager: SecureTokenManager
    @State private var showingTokenSetup = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                // App Icon and Title
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("NoBuddy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your Notion Companion")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                // Features
                VStack(spacing: 24) {
                    FeatureRow(
                        icon: "key.fill",
                        title: "Secure Token Management",
                        description: "Safely store and manage your Notion integration tokens"
                    )
                    
                    FeatureRow(
                        icon: "wand.and.stars",
                        title: "iOS Shortcuts",
                        description: "Create quick actions with Siri and iOS Shortcuts"
                    )
                    
                    FeatureRow(
                        icon: "square.grid.2x2.fill",
                        title: "Widgets",
                        description: "View your Notion data right from your home screen"
                    )
                }
                
                Spacer()
                
                // Get Started Button
                Button(action: {
                    showingTokenSetup = true
                }) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Welcome")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingTokenSetup) {
            NavigationView {
                TokenManagementView()
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Placeholder Views

struct SearchView: View {
    @EnvironmentObject var tokenManager: SecureTokenManager
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText, onSearchButtonClicked: performSearch)
                
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try adjusting your search terms")
                    )
                } else {
                    List(searchResults, id: \.self) { result in
                        SearchResultRow(result: result)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Search")
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty,
              let token = tokenManager.getValidToken() else { return }
        
        isSearching = true
        
        Task {
            do {
                let apiClient = NotionAPIClient()
                let response = try await apiClient.search(
                    query: searchText,
                    token: token.token
                )
                
                await MainActor.run {
                    searchResults = response.results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    // Handle error
                }
            }
        }
    }
}

struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    let onSearchButtonClicked: () -> Void
    
    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.delegate = context.coordinator
        searchBar.placeholder = "Search Notion..."
        searchBar.searchBarStyle = .minimal
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UISearchBarDelegate {
        let parent: SearchBar
        
        init(_ parent: SearchBar) {
            self.parent = parent
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.text = searchText
        }
        
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            parent.onSearchButtonClicked()
            searchBar.resignFirstResponder()
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    
    var body: some View {
        HStack {
            Image(systemName: iconForResult(result))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(titleForResult(result))
                    .font(.headline)
                
                if let subtitle = subtitleForResult(result) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func iconForResult(_ result: SearchResult) -> String {
        switch result {
        case .page:
            return "doc.text"
        case .database:
            return "tablecells"
        }
    }
    
    private func titleForResult(_ result: SearchResult) -> String {
        switch result {
        case .page(let page):
            return "Page" // Would extract title from page properties
        case .database(let database):
            return "Database" // Would extract title from database
        }
    }
    
    private func subtitleForResult(_ result: SearchResult) -> String? {
        switch result {
        case .page(let page):
            return page.url
        case .database(let database):
            return database.url
        }
    }
}

struct QuickActionsView: View {
    @EnvironmentObject var tokenManager: SecureTokenManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    QuickActionCard(
                        title: "Create Page",
                        icon: "doc.badge.plus",
                        color: .blue
                    ) {
                        // Handle create page action
                    }
                    
                    QuickActionCard(
                        title: "Add to Database",
                        icon: "tablecells.badge.ellipsis",
                        color: .green
                    ) {
                        // Handle add to database action
                    }
                    
                    QuickActionCard(
                        title: "Quick Note",
                        icon: "note.text.badge.plus",
                        color: .orange
                    ) {
                        // Handle quick note action
                    }
                    
                    QuickActionCard(
                        title: "Voice Memo",
                        icon: "mic.badge.plus",
                        color: .red
                    ) {
                        // Handle voice memo action
                    }
                }
                .padding()
            }
            .navigationTitle("Quick Actions")
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(SecureTokenManager())
        .environmentObject(DataManager())
}