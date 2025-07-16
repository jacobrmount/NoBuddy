import SwiftUI

@main
struct NoBuddyApp: App {
    @StateObject private var tokenManager = SecureTokenManager()
    @StateObject private var dataManager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tokenManager)
                .environmentObject(dataManager)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Initialize app configuration
        print("NoBuddy app starting...")
        
        // Load existing tokens
        tokenManager.loadTokens()
    }
}