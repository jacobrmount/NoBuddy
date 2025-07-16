import SwiftUI

extension View {
    
    /// Apply conditional modifiers
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply different modifiers based on condition
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if: (Self) -> TrueContent,
        else: (Self) -> FalseContent
    ) -> some View {
        if condition {
            `if`(self)
        } else {
            `else`(self)
        }
    }
    
    /// Hidden modifier based on condition
    @ViewBuilder
    func hidden(_ hidden: Bool) -> some View {
        if hidden {
            self.hidden()
        } else {
            self
        }
    }
    
    /// Rounded corners with specific corners
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    /// Add haptic feedback on tap
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
        }
    }
    
    /// Apply loading overlay
    func loading(_ isLoading: Bool, message: String = "Loading...") -> some View {
        self.overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        
                        Text(message)
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    /// Apply error banner
    func errorBanner(
        error: Binding<String?>,
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        self.overlay(alignment: .top) {
            if let errorMessage = error.wrappedValue {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Button(action: {
                        error.wrappedValue = nil
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color.red)
                .cornerRadius(8)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: error.wrappedValue)
            }
        }
    }
    
    /// Card-like styling
    func cardStyle(
        backgroundColor: Color = Color(.systemBackground),
        shadowRadius: CGFloat = 4,
        cornerRadius: CGFloat = 12
    ) -> some View {
        self
            .padding()
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, x: 0, y: 2)
    }
    
    /// Dismissable on tap outside
    func dismissableOnTapOutside(
        isPresented: Binding<Bool>,
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        ZStack {
            if isPresented.wrappedValue {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isPresented.wrappedValue = false
                        onDismiss()
                    }
            }
            
            self
        }
    }
}

// MARK: - Supporting Views

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}