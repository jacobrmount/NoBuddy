import SwiftUI

/// Main content view with tab navigation
struct ContentView: View {
    @EnvironmentObject var tokenManager: SecureTokenManager
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tokens tab
            TokenManagementView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "key.fill" : "key")
                    Text("Tokens")
                }
                .tag(0)
            
            // Info tab
            SettingsView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "info.circle.fill" : "info.circle")
                    Text("Info")
                }
                .tag(1)
        }
        .accentColor(.blue)
        .background(
            // Glass background effect
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
        )
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SecureTokenManager())
            .preferredColorScheme(.light)
        
        ContentView()
            .environmentObject(SecureTokenManager())
            .preferredColorScheme(.dark)
    }
} 
