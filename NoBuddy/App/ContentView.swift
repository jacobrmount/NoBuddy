import SwiftUI

struct ContentView: View {
    @EnvironmentObject var tokenManager: SecureTokenManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Dashboard")
                }
                .tag(0)
            
            TokenManagementView()
                .tabItem {
                    Image(systemName: "key.fill")
                    Text("Tokens")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .accentColor(.primary)
        .onAppear {
            // Show token management if no tokens exist
            if tokenManager.tokens.isEmpty {
                selectedTab = 1
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SecureTokenManager())
        .environmentObject(DataManager())
}