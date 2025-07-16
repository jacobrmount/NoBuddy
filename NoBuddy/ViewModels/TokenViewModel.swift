import Foundation
import Combine

/// ViewModel for token management views
@MainActor
class TokenViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var tokens: [NotionToken] = []
    @Published var isLoading = false
    @Published var error: TokenError?
    @Published var showingSuccess = false
    @Published var successMessage = ""
    
    // MARK: - Private Properties
    private let tokenManager: SecureTokenManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(tokenManager: SecureTokenManager) {
        self.tokenManager = tokenManager
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func loadTokens() {
        Task {
            await tokenManager.loadTokens()
        }
    }
    
    func addToken(name: String, token: String) {
        Task {
            let success = await tokenManager.addToken(name: name, token: token)
            if success {
                showSuccess("Token added successfully")
            }
        }
    }
    
    func updateToken(_ token: NotionToken, name: String) {
        Task {
            let success = await tokenManager.updateToken(token, name: name)
            if success {
                showSuccess("Token updated successfully")
            }
        }
    }
    
    func deleteToken(_ token: NotionToken) {
        Task {
            let success = await tokenManager.deleteToken(token)
            if success {
                showSuccess("Token deleted successfully")
            }
        }
    }
    
    func validateToken(_ token: NotionToken) {
        Task {
            let result = await tokenManager.validateToken(token)
            if result.isValid {
                showSuccess("Token is valid")
            }
        }
    }
    
    func validateAllTokens() {
        Task {
            await tokenManager.validateAllTokens()
            showSuccess("All tokens validated")
        }
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        tokenManager.$tokens
            .assign(to: \.tokens, on: self)
            .store(in: &cancellables)
        
        tokenManager.$isLoading
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        tokenManager.$error
            .assign(to: \.error, on: self)
            .store(in: &cancellables)
    }
    
    private func showSuccess(_ message: String) {
        successMessage = message
        showingSuccess = true
        
        // Auto-hide success message after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showingSuccess = false
        }
    }
}