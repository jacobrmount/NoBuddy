import SwiftUI

struct TokenManagementView: View {
    @EnvironmentObject var tokenManager: SecureTokenManager
    @StateObject private var viewModel: TokenViewModel
    
    init() {
        // Note: This will be properly initialized when the view appears
        self._viewModel = StateObject(wrappedValue: TokenViewModel(tokenManager: SecureTokenManager()))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if tokenManager.tokens.isEmpty {
                    EmptyTokensView {
                        viewModel.showAddToken()
                    }
                } else {
                    tokensList
                }
                
                if tokenManager.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
            .navigationTitle("Notion Tokens")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Token") {
                        viewModel.showAddToken()
                    }
                }
                
                if !tokenManager.tokens.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Validate All") {
                            Task {
                                await viewModel.validateAllTokens()
                            }
                        }
                        .disabled(tokenManager.isLoading)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddToken) {
                AddTokenView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingEditToken) {
                EditTokenView(viewModel: viewModel)
            }
            .alert("Delete Token", isPresented: $viewModel.showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.deleteToken()
                }
            } message: {
                Text("Are you sure you want to delete this token? This action cannot be undone.")
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
        .onAppear {
            // Properly initialize the view model with the environment object
            viewModel.setTokenManager(tokenManager)
        }
    }
    
    private var tokensList: some View {
        List {
            ForEach(tokenManager.tokens) { token in
                TokenRowView(token: token, viewModel: viewModel)
            }
        }
        .refreshable {
            await viewModel.validateAllTokens()
        }
    }
}

// MARK: - Token Row View

struct TokenRowView: View {
    let token: SafeNotionToken
    let viewModel: TokenViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(token.name)
                        .font(.headline)
                    
                    if let workspaceName = token.workspaceName {
                        Text(workspaceName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                validationStatusBadge
            }
            
            HStack {
                Text("Created \(viewModel.formatDate(token.createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Validate") {
                        Task {
                            await viewModel.validateToken(token)
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                    
                    Button("Edit") {
                        viewModel.showEditToken(token)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                    
                    Button("Delete") {
                        viewModel.confirmDeleteToken(token)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var validationStatusBadge: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Circle()
                .fill(viewModel.validationStatusColor(for: token))
                .frame(width: 8, height: 8)
            
            Text(viewModel.validationStatusText(for: token))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Empty State View

struct EmptyTokensView: View {
    let onAddToken: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.horizontal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Notion Tokens")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add your first Notion integration token to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Add Token") {
                onAddToken()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Add Token View

struct AddTokenView: View {
    @ObservedObject var viewModel: TokenViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            TokenFormView(
                title: "Add Notion Token",
                tokenName: $viewModel.tokenName,
                tokenValue: $viewModel.tokenValue,
                isValidating: viewModel.isValidating,
                errorMessage: viewModel.errorMessage,
                onSave: {
                    Task {
                        await viewModel.addToken()
                    }
                },
                onCancel: {
                    viewModel.clearForm()
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Edit Token View

struct EditTokenView: View {
    @ObservedObject var viewModel: TokenViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            TokenFormView(
                title: "Edit Token",
                tokenName: $viewModel.tokenName,
                tokenValue: $viewModel.tokenValue,
                isValidating: false,
                errorMessage: viewModel.errorMessage,
                isEditMode: true,
                onSave: {
                    viewModel.updateToken()
                    dismiss()
                },
                onCancel: {
                    viewModel.clearForm()
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Token Form View

struct TokenFormView: View {
    let title: String
    @Binding var tokenName: String
    @Binding var tokenValue: String
    let isValidating: Bool
    let errorMessage: String?
    var isEditMode: Bool = false
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTokenNameFocused: Bool
    @FocusState private var isTokenValueFocused: Bool
    
    var body: some View {
        Form {
            Section {
                TextField("Token Name", text: $tokenName)
                    .focused($isTokenNameFocused)
                    .textInputAutocapitalization(.words)
                
                if !isEditMode {
                    TextField("Integration Token", text: $tokenValue)
                        .focused($isTokenValueFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.monospaced(.body)())
                }
            } header: {
                Text("Token Information")
            } footer: {
                if !isEditMode {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To get your Notion integration token:")
                        Text("1. Go to notion.so/my-integrations")
                        Text("2. Create a new integration")
                        Text("3. Copy the Internal Integration Token")
                        Text("4. Make sure to share your databases with this integration")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onCancel()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    onSave()
                }
                .disabled(tokenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                         (!isEditMode && tokenValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ||
                         isValidating)
            }
        }
        .onAppear {
            if !isEditMode {
                isTokenNameFocused = true
            }
        }
        .overlay {
            if isValidating {
                ProgressView("Validating token...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
    }
}

#Preview {
    TokenManagementView()
        .environmentObject(SecureTokenManager())
}