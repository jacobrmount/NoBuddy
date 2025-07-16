import SwiftUI

struct TokenManagementView: View {
    
    // MARK: - Environment Objects
    @EnvironmentObject var tokenManager: SecureTokenManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var showingAddToken = false
    @State private var showingEditToken: NotionToken?
    @State private var showingDeleteAlert = false
    @State private var tokenToDelete: NotionToken?
    @State private var isValidatingAll = false
    
    var body: some View {
        NavigationView {
            VStack {
                if tokenManager.isLoading {
                    ProgressView("Loading tokens...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if tokenManager.tokens.isEmpty {
                    EmptyTokensView(showingAddToken: $showingAddToken)
                } else {
                    TokensList()
                }
            }
            .navigationTitle("Tokens")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !tokenManager.tokens.isEmpty {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !tokenManager.tokens.isEmpty {
                            Button("Validate All") {
                                validateAllTokens()
                            }
                            .disabled(isValidatingAll)
                        }
                        
                        Button("Add Token") {
                            showingAddToken = true
                        }
                    }
                }
            }
            .alert("Delete Token", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let token = tokenToDelete {
                        deleteToken(token)
                    }
                }
            } message: {
                if let token = tokenToDelete {
                    Text("Are you sure you want to delete '\(token.name)'? This action cannot be undone.")
                }
            }
            .sheet(isPresented: $showingAddToken) {
                AddTokenView()
            }
            .sheet(item: $showingEditToken) { token in
                EditTokenView(token: token)
            }
        }
    }
    
    // MARK: - Private Views
    
    @ViewBuilder
    private func TokensList() -> some View {
        List {
            ForEach(tokenManager.tokens) { token in
                TokenRow(
                    token: token,
                    onEdit: { showingEditToken = token },
                    onDelete: { confirmDelete(token) },
                    onValidate: { validateToken(token) }
                )
            }
        }
        .refreshable {
            await tokenManager.loadTokens()
        }
    }
    
    // MARK: - Private Methods
    
    private func validateAllTokens() {
        isValidatingAll = true
        Task {
            await tokenManager.validateAllTokens()
            await MainActor.run {
                isValidatingAll = false
            }
        }
    }
    
    private func validateToken(_ token: NotionToken) {
        Task {
            _ = await tokenManager.validateToken(token)
        }
    }
    
    private func confirmDelete(_ token: NotionToken) {
        tokenToDelete = token
        showingDeleteAlert = true
    }
    
    private func deleteToken(_ token: NotionToken) {
        Task {
            _ = await tokenManager.deleteToken(token)
        }
    }
}

// MARK: - Empty State View

struct EmptyTokensView: View {
    @Binding var showingAddToken: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "key.radiowaves.forward")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Tokens")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add your first Notion integration token to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Add Your First Token") {
                showingAddToken = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Token Row

struct TokenRow: View {
    let token: NotionToken
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onValidate: () -> Void
    
    @EnvironmentObject var tokenManager: SecureTokenManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with name and status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(token.displayName)
                        .font(.headline)
                    
                    Text(token.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ValidationStatusBadge(token: token)
            }
            
            // Token details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Token:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(token.maskedToken)
                        .font(.caption.monospaced())
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                if let workspaceName = token.workspaceName {
                    HStack {
                        Text("Workspace:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(workspaceName)
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
                
                HStack {
                    Text("Created:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(token.createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                if let lastValidated = token.lastValidated {
                    HStack {
                        Text("Last validated:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(lastValidated, style: .relative)
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
            }
            
            // Action buttons
            HStack {
                Button("Validate") {
                    onValidate()
                }
                .buttonStyle(.bordered)
                .disabled(tokenManager.isLoading)
                
                Button("Edit") {
                    onEdit()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Delete") {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("Validate") {
                onValidate()
            }
            
            Button("Edit") {
                onEdit()
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - Validation Status Badge

struct ValidationStatusBadge: View {
    let token: NotionToken
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption)
            
            Text(statusText)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(8)
    }
    
    private var iconName: String {
        if token.isValid {
            return "checkmark.circle.fill"
        } else if token.lastValidated != nil {
            return "xmark.circle.fill"
        } else {
            return "questionmark.circle.fill"
        }
    }
    
    private var statusText: String {
        if token.isValid {
            return "Valid"
        } else if token.lastValidated != nil {
            return "Invalid"
        } else {
            return "Unknown"
        }
    }
    
    private var backgroundColor: Color {
        if token.isValid {
            return .green.opacity(0.2)
        } else if token.lastValidated != nil {
            return .red.opacity(0.2)
        } else {
            return .gray.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        if token.isValid {
            return .green
        } else if token.lastValidated != nil {
            return .red
        } else {
            return .gray
        }
    }
}

// MARK: - Add Token View

struct AddTokenView: View {
    @EnvironmentObject var tokenManager: SecureTokenManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var tokenName = ""
    @State private var tokenValue = ""
    @State private var isValidating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Token Name", text: $tokenName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Token", text: $tokenValue)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                } header: {
                    Text("Token Details")
                } footer: {
                    Text("Enter a name to identify this token and the actual integration token from Notion.")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to get a Notion integration token:")
                            .font(.headline)
                        
                        HStack(alignment: .top) {
                            Text("1.")
                                .fontWeight(.semibold)
                            Text("Go to notion.so/my-integrations")
                        }
                        
                        HStack(alignment: .top) {
                            Text("2.")
                                .fontWeight(.semibold)
                            Text("Create a new integration")
                        }
                        
                        HStack(alignment: .top) {
                            Text("3.")
                                .fontWeight(.semibold)
                            Text("Copy the Integration Token")
                        }
                        
                        HStack(alignment: .top) {
                            Text("4.")
                                .fontWeight(.semibold)
                            Text("Share your databases with the integration")
                        }
                    }
                } header: {
                    Text("Instructions")
                }
            }
            .navigationTitle("Add Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveToken()
                    }
                    .disabled(tokenName.isEmpty || tokenValue.isEmpty || isValidating)
                }
            }
            .disabled(isValidating)
            .overlay {
                if isValidating {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Validating token...")
                            .padding(.top)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveToken() {
        guard !tokenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !tokenValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isValidating = true
        
        Task {
            let success = await tokenManager.addToken(
                name: tokenName.trimmingCharacters(in: .whitespacesAndNewlines),
                token: tokenValue.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            await MainActor.run {
                isValidating = false
                
                if success {
                    dismiss()
                } else {
                    errorMessage = tokenManager.error?.localizedDescription ?? "Failed to add token"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Edit Token View

struct EditTokenView: View {
    let token: NotionToken
    
    @EnvironmentObject var tokenManager: SecureTokenManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var tokenName: String
    @State private var isUpdating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(token: NotionToken) {
        self.token = token
        _tokenName = State(initialValue: token.name)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Token Name", text: $tokenName)
                        .textInputAutocapitalization(.words)
                    
                    HStack {
                        Text("Token:")
                        Spacer()
                        Text(token.maskedToken)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Token Details")
                } footer: {
                    Text("You can only change the name. To update the token value, delete this token and add a new one.")
                }
                
                Section {
                    if let workspaceName = token.workspaceName {
                        LabeledContent("Workspace", value: workspaceName)
                    }
                    
                    LabeledContent("Created", value: token.createdAt.formatted(date: .abbreviated, time: .shortened))
                    
                    if let lastValidated = token.lastValidated {
                        LabeledContent("Last Validated", value: lastValidated.formatted(date: .abbreviated, time: .shortened))
                    }
                    
                    LabeledContent("Status") {
                        ValidationStatusBadge(token: token)
                    }
                } header: {
                    Text("Information")
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
                    Button("Save") {
                        updateToken()
                    }
                    .disabled(tokenName.isEmpty || isUpdating || tokenName == token.name)
                }
            }
            .disabled(isUpdating)
            .overlay {
                if isUpdating {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Updating token...")
                            .padding(.top)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func updateToken() {
        guard !tokenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isUpdating = true
        
        Task {
            let success = await tokenManager.updateToken(
                token,
                name: tokenName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            await MainActor.run {
                isUpdating = false
                
                if success {
                    dismiss()
                } else {
                    errorMessage = tokenManager.error?.localizedDescription ?? "Failed to update token"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TokenManagementView()
        .environmentObject(SecureTokenManager())
}