import Foundation
import Combine
import SwiftUI

/// ViewModel for token management views
@MainActor
class TokenViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var showingAddToken = false
    @Published var showingEditToken = false
    @Published var selectedToken: SafeNotionToken?
    @Published var isValidating = false
    @Published var showingDeleteAlert = false
    @Published var tokenToDelete: SafeNotionToken?
    
    // Form fields
    @Published var tokenName = ""
    @Published var tokenValue = ""
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    
    private var tokenManager: SecureTokenManager?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(tokenManager: SecureTokenManager? = nil) {
        self.tokenManager = tokenManager
        
        // Subscribe to token manager errors if available
        if let manager = tokenManager {
            manager.$errorMessage
                .assign(to: \.errorMessage, on: self)
                .store(in: &cancellables)
        }
    }
    
    func setTokenManager(_ manager: SecureTokenManager) {
        self.tokenManager = manager
        
        // Clear existing subscriptions
        cancellables.removeAll()
        
        // Subscribe to token manager errors
        manager.$errorMessage
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Show add token sheet
    func showAddToken() {
        clearForm()
        showingAddToken = true
    }
    
    /// Show edit token sheet
    func showEditToken(_ token: SafeNotionToken) {
        selectedToken = token
        tokenName = token.name
        tokenValue = "" // Don't pre-fill token value for security
        showingEditToken = true
    }
    
    /// Add a new token
    func addToken() async {
        guard let tokenManager = tokenManager else {
            errorMessage = "Token manager not available"
            return
        }
        
        guard !tokenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !tokenValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please fill in all required fields"
            return
        }
        
        isValidating = true
        defer { isValidating = false }
        
        do {
            try await tokenManager.addToken(name: tokenName, token: tokenValue)
            clearForm()
            showingAddToken = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Update an existing token
    func updateToken() {
        guard let tokenManager = tokenManager else {
            errorMessage = "Token manager not available"
            return
        }
        
        guard let token = selectedToken,
              !tokenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a valid token name"
            return
        }
        
        do {
            try tokenManager.updateToken(token.id, name: tokenName)
            clearForm()
            showingEditToken = false
            selectedToken = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Show delete confirmation
    func confirmDeleteToken(_ token: SafeNotionToken) {
        tokenToDelete = token
        showingDeleteAlert = true
    }
    
    /// Delete a token
    func deleteToken() {
        guard let tokenManager = tokenManager else {
            errorMessage = "Token manager not available"
            return
        }
        
        guard let token = tokenToDelete else { return }
        
        do {
            try tokenManager.deleteToken(token.id)
            tokenToDelete = nil
            showingDeleteAlert = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Validate all tokens
    func validateAllTokens() async {
        guard let tokenManager = tokenManager else {
            errorMessage = "Token manager not available"
            return
        }
        
        await tokenManager.validateAllTokens()
    }
    
    /// Validate a specific token
    func validateToken(_ token: SafeNotionToken) async {
        guard let tokenManager = tokenManager else {
            errorMessage = "Token manager not available"
            return
        }
        
        isValidating = true
        defer { isValidating = false }
        
        do {
            let tokenValue = try tokenManager.getToken(token.id)
            let apiClient = NotionAPIClient()
            let result = await apiClient.validateToken(tokenValue)
            
            switch result {
            case .valid:
                // Token manager will update the token status
                break
            case .invalid(let error):
                errorMessage = "Token validation failed: \(error)"
            case .networkError(let error):
                errorMessage = "Network error during validation: \(error)"
            }
        } catch {
            errorMessage = "Failed to validate token: \(error.localizedDescription)"
        }
    }
    
    /// Clear form fields
    func clearForm() {
        tokenName = ""
        tokenValue = ""
        selectedToken = nil
        errorMessage = nil
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
        tokenManager?.clearError()
    }
    
    /// Format date for display
    func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Get validation status text
    func validationStatusText(for token: SafeNotionToken) -> String {
        if let lastValidated = token.lastValidated {
            if token.isValid {
                return "Valid • \(formatDate(lastValidated))"
            } else {
                return "Invalid • \(formatDate(lastValidated))"
            }
        } else {
            return "Not validated"
        }
    }
    
    /// Get validation status color
    func validationStatusColor(for token: SafeNotionToken) -> Color {
        if token.lastValidated != nil {
            return token.isValid ? .green : .red
        } else {
            return .orange
        }
    }
}