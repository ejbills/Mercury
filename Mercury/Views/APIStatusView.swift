import SwiftUI

struct APIStatusView: View {
    @Binding var clientId: String
    @Binding var isSetupComplete: Bool
    let apiService: RedditAPIManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        StatusIcon(status: apiService.apiStatus)
                        statusText
                    }
                    .padding(.top, 32)
                    
                    if let userInfo = apiService.userInfo {
                        userInfoCard(userInfo)
                    }
                    
                    if let errorMessage = apiService.errorMessage {
                        errorCard(errorMessage)
                    }
                    
                    actionButtons
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("API Status")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if apiService.accessToken == nil {
                    apiService.startOAuthFlow()
                } else {
                    Task {
                        await apiService.validateCredentials()
                    }
                }
            }
            .refreshable {
                await apiService.validateCredentials()
            }
        }
    }
    
    private var statusText: VStack<some View> {
        VStack(spacing: 8) {
            Text(statusTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(statusDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private func userInfoCard(_ user: RedditUser) -> some View {
        MaterialCard {
            SectionHeader(icon: "person.circle.fill", title: "Account Details", color: .blue)
            
            VStack(spacing: 16) {
                InfoRow(label: "Username", value: "/u/\(user.name)")
                InfoRow(label: "Link Karma", value: "\(user.linkKarma.formatted())")
                InfoRow(label: "Comment Karma", value: "\(user.commentKarma.formatted())")
                InfoRow(label: "Total Karma", value: "\(user.totalKarma.formatted())")
                InfoRow(label: "Account Created", value: user.accountAge)
                InfoRow(label: "Email Verified", value: user.hasVerifiedEmail ? "Yes" : "No")
            }
            .padding(.leading, 36)
        }
    }
    
    private func errorCard(_ message: String) -> some View {
        MaterialCard {
            SectionHeader(icon: "exclamationmark.triangle.fill", title: "Error Details", color: .red)
            
            VStack(alignment: .leading, spacing: 12) {
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 36)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemRed).opacity(0.3), lineWidth: 1)
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            PrimaryButton(
                apiService.accessToken == nil ? "Authenticate with Reddit" : "Test Connection",
                icon: apiService.accessToken == nil ? "globe" : "arrow.clockwise",
                isLoading: apiService.apiStatus == .validating
            ) {
                if apiService.accessToken == nil {
                    apiService.startOAuthFlow()
                } else {
                    Task {
                        await apiService.validateCredentials()
                    }
                }
            }
            
            SecondaryButton(
                "Change Credentials",
                icon: "pencil"
            ) {
                apiService.clearStoredCredentials()
                isSetupComplete = false
            }
        }
        .padding(.horizontal, 8)
    }
    
    
    private var statusTitle: String {
        switch apiService.apiStatus {
        case .unknown:
            return "Ready to Test"
        case .validating:
            return "Validating..."
        case .valid:
            return "Connected"
        case .invalid:
            return "Authentication Failed"
        case .networkError:
            return "Connection Error"
        }
    }
    
    private var statusDescription: String {
        switch apiService.apiStatus {
        case .unknown:
            return "Tap 'Test Connection' to verify your Reddit API credentials"
        case .validating:
            return "Checking your Reddit API credentials"
        case .valid:
            return "Your Reddit API connection is working perfectly"
        case .invalid:
            return "There's an issue with your Personal Access Token"
        case .networkError:
            return "Unable to connect to Reddit's servers"
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    APIStatusView(
        clientId: .constant("sample_client_id"),
        isSetupComplete: .constant(true),
        apiService: RedditAPIManager()
    )
}
