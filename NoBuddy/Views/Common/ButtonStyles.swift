import SwiftUI

// MARK: - Button Styles

/// Glass morphism button style with subtle effects
struct GlassButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
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
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Custom button style that provides a scale animation on press
struct NoBuddyScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
