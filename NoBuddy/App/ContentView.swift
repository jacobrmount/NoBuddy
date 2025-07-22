import SwiftUI

/// Main content view with tab navigation
struct ContentView: View {
    @EnvironmentObject var tokenManager: SecureTokenManager
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTab = 0
    
    @State private var debugOutput: String = ""
    
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
            
            // Debug tab (temporary)
            VStack {
                Text("App Group Debug")
                    .font(.title)
                    .padding()
                
                Button("Test App Group") {
                    testAppGroup()
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                Button("Force Create Container") {
                    forceCreateContainer()
                }
                .buttonStyle(.bordered)
                .padding()
                
                ScrollView {
                    Text(debugOutput)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                }
            }
            .tabItem {
                Image(systemName: "hammer")
                Text("Debug")
            }
            .tag(2)
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
    private func testAppGroup() {
        let appGroupID = "group.com.nobuddy.app"
        var output = "\n=== App Group Debug ===\n"
        output += "App Group ID: \(appGroupID)\n"
        
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            output += "✅ Container URL: \(containerURL.path)\n"
            let exists = FileManager.default.fileExists(atPath: containerURL.path)
            output += "Directory exists: \(exists)\n"
        } else {
            output += "❌ Failed to get container URL\n"
        }
        
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            let testKey = "app_group_test"
            let testValue = "Test Value"
            sharedDefaults.set(testValue, forKey: testKey)
            sharedDefaults.synchronize()
            if let readValue = sharedDefaults.string(forKey: testKey) {
                output += "✅ UserDefaults value: \(readValue)\n"
                sharedDefaults.removeObject(forKey: testKey)
            } else {
                output += "❌ Failed to read UserDefaults\n"
            }
        } else {
            output += "❌ Failed to create UserDefaults\n"
        }
        
        debugOutput = output
    }
    
    private func forceCreateContainer() {
        let appGroupID = "group.com.nobuddy.app"
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let markerURL = containerURL.appendingPathComponent(".nobuddy_initialized")
            do {
                try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
                let markerData = "Initialized at \(Date())".data(using: .utf8)!
                try markerData.write(to: markerURL)
                testAppGroup() // Re-run test to update state
            } catch {
                debugOutput = "❌ Failed to create marker file: \(error)\n"
            }
        } else {
            debugOutput = "❌ Failed to get container URL for write\n"
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
} 
