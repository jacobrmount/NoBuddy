import SwiftUI

/// Main view for managing Notion API tokens
struct TokenManagementView: View {
    @StateObject private var tokenManager = SecureTokenManager()
    @State private var showingAddToken = false
    @State private var showingDeleteAlert = false
    @State private var tokenToDelete: NotionToken? = nil
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background with glass morphism effect
                backgroundView
                
                VStack(spacing: 0) {
                    if tokenManager.tokens.isEmpty {
                        emptyStateView
                    } else {
                        tokenListView
                    }
                }
                
                // Floating Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingAddButton
                            .padding(.trailing, 20)
                            .padding(.bottom, 100) // Above tab bar
                    }
                }
            }
            .navigationTitle("Tokens")
            .navigationBarTitleDisplayMode(.large)
            // Remove the toolbar section completely
            .sheet(isPresented: $showingAddToken) {
                AddTokenView(tokenManager: tokenManager)
            }
            .alert("Delete Token", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let token = tokenToDelete {
                        Task {
                            await tokenManager.deleteToken(token)
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let token = tokenToDelete {
                    Text("Are you sure you want to delete '\(token.name)'? This action cannot be undone.")
                }
            }
        }
        .preferredColorScheme(nil) // Respect system setting
        .task {
            await tokenManager.loadTokens()
        }
    }
    
    // MARK: - Background View
    
    private var backgroundView: some View {
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
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Star icon with glass effect
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                Image(systemName: "star.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("No tokens add yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Click the plus to add your first Notion integration")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Token List View
    
    private var tokenListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tokenManager.tokens) { token in
                    TokenRowView(
                        token: token,
                        onTap: {
                            // For now, just show token name in console
                            print("Tapped token: \(token.name)")
                        },
                        onDelete: {
                            tokenToDelete = token
                            showingDeleteAlert = true
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .refreshable {
            await tokenManager.loadTokens()
        }
    }
    
    // MARK: - Add Button (Updated to Floating)
    
    private var floatingAddButton: some View {
        Button(action: { showingAddToken = true }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(NoBuddyScaleButtonStyle())
    }
    
    // Keep the old addButton for reference but make it private
    private var addButton: some View {
        Button(action: { showingAddToken = true }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(NoBuddyScaleButtonStyle())
    }
    
    // MARK: - Token Row View
    
    struct TokenRowView: View {
        let token: NotionToken
        let onTap: () -> Void
        let onDelete: () -> Void
        
        @State private var isEnabled = true
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Token icon/workspace info
                    tokenIcon
                    
                    // Token details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(token.displayName)
                            .font(.system(.body, design: .default, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("Last edited \(formatDate(token.lastValidated ?? token.createdAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Toggle switch
                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .scaleEffect(0.9)
                    
                    // Delete button
                    Button(action: onDelete) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                    .buttonStyle(NoBuddyScaleButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
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
            .buttonStyle(PlainButtonStyle())
        }
        
        private var tokenIcon: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: token.isValid
                            ? [.green.opacity(0.7), .blue.opacity(0.7)]
                            : [.gray.opacity(0.5), .gray.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                if let workspaceIcon = token.workspaceIcon, !workspaceIcon.isEmpty {
                    AsyncImage(url: URL(string: workspaceIcon)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "building.2")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "building.2")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                }
                
                // Status indicator
                if !token.isValid {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(.red)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                )
                        }
                    }
                }
            }
        }
        
        private func formatDate(_ date: Date) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }
    }
    
    // MARK: - Preview
    
    struct TokenManagementView_Previews: PreviewProvider {
        static var previews: some View {
            TokenManagementView()
                .preferredColorScheme(.light)
            
            TokenManagementView()
                .preferredColorScheme(.dark)
        }
    }
}
