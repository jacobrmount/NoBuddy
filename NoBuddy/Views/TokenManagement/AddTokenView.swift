import SwiftUI

/// View for adding a new Notion API token
struct AddTokenView: View {
    @ObservedObject var tokenManager: SecureTokenManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var tokenName = ""
    @State private var tokenValue = ""
    @State private var isValidating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingIntegrationFlow = false
    
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
                        
                        // Before you begin section
                        beforeBeginSection
                        
                        // Form section
                        formSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Add token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    saveButton
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingIntegrationFlow) {
                NotionIntegrationFlowView()
            }
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
                
                Image(systemName: "plus.circle.fill")
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
    
    // MARK: - Before Begin Section
    
    private var beforeBeginSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("Before you begin")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                stepView(
                    number: "1",
                    title: "Go to your Notion workspace",
                    description: "Sign in to your Notion account in a web browser"
                )
                
                stepView(
                    number: "2",
                    title: "Navigate to Settings & Members >",
                    description: "Integrations"
                )
                
                stepView(
                    number: "3",
                    title: "Create a new integration and copy",
                    description: "the token"
                )
            }
            
            Button(action: { showingIntegrationFlow = true }) {
                HStack {
                    Text("Open Notion Integration")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.3), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .foregroundColor(.primary)
            }
            .buttonStyle(NoBuddyScaleButtonStyle())
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
                    .textFieldStyle(GlassTextFieldStyle())
                    .autocorrectionDisabled()
            }
            
            // Secret field
            VStack(alignment: .leading, spacing: 8) {
                Text("Secret")
                    .font(.headline)
                    .fontWeight(.medium)
                
                SecureField("", text: $tokenValue)
                    .textFieldStyle(GlassTextFieldStyle())
                    .autocorrectionDisabled()
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
    
    // MARK: - Helper Views
    
    private func stepView(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 24, height: 24)
                
                Text(number)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func saveToken() {
        Task {
            isValidating = true
            
            let result = await tokenManager.addToken(
                name: tokenName.trimmingCharacters(in: .whitespacesAndNewlines),
                token: tokenValue.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
            
            isValidating = false
        }
    }
}

// MARK: - Glass Text Field Style

struct GlassTextFieldStyle: TextFieldStyle {
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

// MARK: - Notion Integration Flow View

struct NotionIntegrationFlowView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("This would open Notion's integration setup page")
                    .font(.headline)
                    .padding()
                
                Text("https://www.notion.so/my-integrations")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding()
            }
            .navigationTitle("Notion Integration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct AddTokenView_Previews: PreviewProvider {
    static var previews: some View {
        AddTokenView(tokenManager: SecureTokenManager())
            .preferredColorScheme(.light)
        
        AddTokenView(tokenManager: SecureTokenManager())
            .preferredColorScheme(.dark)
    }
} 
