import SwiftUI

@main
struct NoBuddyApp: App {
    @StateObject private var tokenManager = SecureTokenManager()
    
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tokenManager)
                .preferredColorScheme(nil) // Respect system setting
        }
    }
}
