import SwiftUI
import WidgetKit

/// View for editing a Notion API token and selecting databases
struct EditTokenView: View {
    let token: NotionToken
    @ObservedObject var tokenManager: SecureTokenManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var tokenName: String
    @State private var tokenValue: String
    @State private var databases: [NotionDatabase] = []
    @State private var selectedDatabaseIds: Set<String> = []
    @State private var isLoadingDatabases = false
    @State private var isValidating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isRefreshing = false
    
    private let storage = DatabaseStorage()
    private var notionClient: NotionAPIClient { NotionAPIClient(token: tokenValue) }
    
    init(token: NotionToken, tokenManager: SecureTokenManager) {
        self.token = token
        self.tokenManager = tokenManager
        self._tokenName = State(initialValue: token.name)
        self._tokenValue = State(initialValue: token.token)
    }
    
    private var isFormValid: Bool {
        !tokenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !tokenValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background with glass morphism effect
                backgroundView
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header section
                        headerSection
                        
                        // Database selection section (replaces "Before you begin")
                        databaseSection
                        
                        // Form section
                        formSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .refreshable {
                    await refreshDatabases()
                }
            }
            .navigationTitle("Edit Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Refresh button
                        Button(action: {
                            Task {
                                await refreshDatabases()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .disabled(isRefreshing || tokenValue.isEmpty)
                        .opacity(isRefreshing ? 0.5 : 1.0)
                        
                        saveButton
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadDatabases()
            loadSelectedDatabases()
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)
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
                
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
    }
    
    // MARK: - Database Section
    
    private var databaseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "rectangle.grid.3x2.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("Select Databases")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !selectedDatabaseIds.isEmpty {
                    Text("\(selectedDatabaseIds.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.blue)
                        )
                }
            }
            
            if isLoadingDatabases {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading databases...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else if databases.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("No databases found")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Make sure this token has access to databases")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(databases) { database in
                                DatabaseRowView(
                                    database: database,
                                    isSelected: selectedDatabaseIds.contains(database.id),
                                    onToggle: {
                                        toggleDatabaseSelection(database.id)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 200) // Limit height to make it scrollable
                    
                    // Refresh button
                    Button(action: {
                        Task {
                            await refreshDatabases()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                            Text("Refresh")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isRefreshing)
                }
            }
        }
        .padding(20)
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
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: 20) {
            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.headline)
                    .fontWeight(.medium)
                
                TextField("Workspace", text: $tokenName)
                    .textFieldStyle(EditTokenGlassTextFieldStyle())
                    .autocorrectionDisabled()
            }
            
            // Secret field
            VStack(alignment: .leading, spacing: 8) {
                Text("Secret")
                    .font(.headline)
                    .fontWeight(.medium)
                
                SecureField("", text: $tokenValue)
                    .textFieldStyle(EditTokenGlassTextFieldStyle())
                    .autocorrectionDisabled()
                    .onChange(of: tokenValue) {
                        // Reload databases when token changes
                        if !tokenValue.isEmpty {
                            loadDatabases()
                        }
                    }
            }
        }
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button(action: saveToken) {
            if isValidating {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Text("Save")
                    .fontWeight(.medium)
            }
        }
        .disabled(!isFormValid || isValidating)
    }
    
    // MARK: - Actions
    
    private func loadDatabases() {
        guard !tokenValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            databases = []
            return
        }
        
        Task {
            await MainActor.run {
                isLoadingDatabases = true
            }
            
            do {
                let client = NotionAPIClient(token: tokenValue.trimmingCharacters(in: .whitespacesAndNewlines))
                let fetchedDatabases = try await client.searchDatabases()
                
                await MainActor.run {
                    databases = fetchedDatabases
                    isLoadingDatabases = false
                }
                
                print("✅ Loaded \(fetchedDatabases.count) databases for token editing")
            } catch {
                await MainActor.run {
                    databases = []
                    isLoadingDatabases = false
                }
                
                print("❌ Failed to load databases: \(error)")
            }
        }
    }
    
    private func loadSelectedDatabases() {
        let savedIds = storage.loadSelectedDatabases()
        selectedDatabaseIds = Set(savedIds)
    }
    
    private func toggleDatabaseSelection(_ databaseId: String) {
        if selectedDatabaseIds.contains(databaseId) {
            selectedDatabaseIds.remove(databaseId)
        } else {
            selectedDatabaseIds.insert(databaseId)
        }
        
        // Save immediately
        let selectedArray = Array(selectedDatabaseIds)
        storage.saveSelectedDatabases(selectedArray)
        
        print("🔄 Toggled database \(databaseId): \(selectedDatabaseIds.contains(databaseId))")
    }
    
    private func refreshDatabases() async {
        guard !tokenValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        await MainActor.run {
            isRefreshing = true
        }
        
        do {
            // Clear cached data first
            WidgetUpdateHelper.clearDatabasesCache()
            
            // Create updated token for refresh
            let currentToken = NotionToken(
                name: tokenName.trimmingCharacters(in: .whitespacesAndNewlines),
                token: tokenValue.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            // Fetch fresh databases
            let fetchedDatabases = try await tokenManager.refreshDatabases(for: currentToken)
            
            await MainActor.run {
                databases = fetchedDatabases
                isRefreshing = false
                
                // Trigger widget updates
                WidgetCenter.shared.reloadAllTimelines()
            }
            
            // Provide haptic feedback on successful refresh
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
            
            print("✅ Refreshed \(fetchedDatabases.count) databases")
        } catch {
            await MainActor.run {
                isRefreshing = false
                errorMessage = "Failed to refresh databases: \(error.localizedDescription)"
                showingError = true
            }
            
            print("❌ Failed to refresh databases: \(error)")
        }
    }
    
    private func saveToken() {
        Task {
            isValidating = true
            
            // Create updated token
            let updatedToken = NotionToken(
                name: tokenName.trimmingCharacters(in: .whitespacesAndNewlines),
                token: tokenValue.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            // Try to update the token (delete old, add new)
            let deleteResult = await tokenManager.deleteToken(id: token.id)
            
            switch deleteResult {
            case .success:
                let addResult = await tokenManager.addToken(
                    name: updatedToken.name,
                    token: updatedToken.token
                )
                
                switch addResult {
                case .success:
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
            
            isValidating = false
        }
    }
}

// MARK: - Database Row View

struct DatabaseRowView: View {
    let database: NotionDatabase
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                // Database icon
                Text(database.icon?.displayIcon ?? "📋")
                    .font(.body)
                
                // Database info
                VStack(alignment: .leading, spacing: 2) {
                    Text(database.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("Updated \(database.safeLastEditedTime, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? .blue.opacity(0.1) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? .blue.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Glass Text Field Style

private struct EditTokenGlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
    }
}

// MARK: - Preview

struct EditTokenView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleToken = NotionToken(name: "Sample Workspace", token: "secret_sample")
        EditTokenView(token: sampleToken, tokenManager: SecureTokenManager())
            .preferredColorScheme(.light)
        
        EditTokenView(token: sampleToken, tokenManager: SecureTokenManager())
            .preferredColorScheme(.dark)
    }
}