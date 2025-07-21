import SwiftUI
import Foundation
import Combine
import Network

// MARK: - View Extensions

extension View {
    /// Apply glass morphism background effect
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
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
    
    /// Apply conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Color Extensions

extension Color {
    /// Custom app colors
    static let appBlue = Color(red: 0.0, green: 0.5, blue: 1.0)
    static let appPurple = Color(red: 0.5, green: 0.0, blue: 1.0)
    static let appGreen = Color(red: 0.0, green: 0.8, blue: 0.4)
    
    /// Glass morphism background colors
    static func glassBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.3)
            : Color.white.opacity(0.7)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Format date for relative display
    func relativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Format date for widget display
    func widgetFormatted() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
    
    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Check if date is overdue
    var isOverdue: Bool {
        self < Date()
    }
}

// MARK: - String Extensions

extension String {
    /// Validate Notion token format
    var isValidNotionToken: Bool {
        let secretPattern = "^secret_[A-Za-z0-9]{43}$"
        let internalPattern = "^ntn_[A-Za-z0-9]{46}$"  // ← Changed from 36 to 46
        
        let secretRegex = try? NSRegularExpression(pattern: secretPattern)
        let internalRegex = try? NSRegularExpression(pattern: internalPattern)
        
        let range = NSRange(location: 0, length: self.utf16.count)
        
        return secretRegex?.firstMatch(in: self, options: [], range: range) != nil ||
               internalRegex?.firstMatch(in: self, options: [], range: range) != nil
    }
    
    /// Mask sensitive content for display
    func masked(showFirst: Int = 8) -> String {
        guard self.count > showFirst else {
            return String(repeating: "•", count: self.count)
        }
        let prefix = String(self.prefix(showFirst))
        let suffix = String(repeating: "•", count: self.count - showFirst)
        return prefix + suffix
    }
}

// MARK: - Environment Values

private struct HapticsEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var hapticsEnabled: Bool {
        get { self[HapticsEnabledKey.self] }
        set { self[HapticsEnabledKey.self] = newValue }
    }
}

// MARK: - Network Reachability

@MainActor
class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Loading States

enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case failed(Error)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var value: T? {
        if case .loaded(let value) = self { return value }
        return nil
    }
    
    var error: Error? {
        if case .failed(let error) = self { return error }
        return nil
    }
}

// MARK: - App Constants

enum AppConstants {
    static let appName = "NoBuddy"
    static let appVersion = "1.0.0"
    static let notionAPIVersion = "2022-06-28"
    static let notionBaseURL = "https://api.notion.com/v1"
    static let appGroupIdentifier = "group.com.nobuddy.shared"
    static let keychainService = "com.nobuddy.app.tokens"
    
    enum UserDefaults {
        static let tokenListKey = "saved_tokens"
        static let isDarkModeEnabled = "isDarkModeEnabled"
        static let isHapticsEnabled = "isHapticsEnabled"
    }
    
    enum Widget {
        static let kind = "NoBuddyWidget"
        static let displayName = "Task List"
        static let description = "Shows your Notion tasks and to-dos"
        static let refreshInterval: TimeInterval = 15 * 60 // 15 minutes
    }
}

