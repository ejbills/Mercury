//
//  OAuthSetupView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct OAuthSetupView: View {
    @Binding var clientId: String
    @Binding var isSetupComplete: Bool
    let apiService: RedditAPIService
    @State private var showingCopiedFeedback = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 64, weight: .thin))
                            .foregroundStyle(Color.accentColor.gradient)
                            .padding(.top, 20)
                        
                        Text("Reddit API Tester")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Full Reddit API access for testing and development")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                    
                    // Instructions
                    VStack(spacing: 24) {
                        MaterialCard {
                            SectionHeader(icon: "1.circle.fill", title: "Create Reddit App")
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Link("Open Reddit Apps", destination: URL(string: "https://reddit.com/prefs/apps")!)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .padding(.leading, 36)
                        }
                        
                        MaterialCard {
                            SectionHeader(icon: "2.circle.fill", title: "Configure App")
                            
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("APP TYPE")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                    
                                    Text("Installed App")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                                }
                                
                                CopyableField(
                                    label: "Redirect URI",
                                    value: "mercury://oauth",
                                    showingCopied: $showingCopiedFeedback
                                )
                            }
                            .padding(.leading, 36)
                        }
                        
                        MaterialCard {
                            SectionHeader(icon: "3.circle.fill", title: "Get Client ID")
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Copy your app's Client ID")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 36)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    
                    // Token Input
                    MaterialCard {
                        SectionHeader(icon: "key.fill", title: "Client ID")
                        
                        VStack(alignment: .leading, spacing: 12) {
                            PasteableTextField(
                                placeholder: "Enter your Reddit Client ID",
                                text: $clientId
                            )
                        }
                        .padding(.leading, 36)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    
                    // Continue Button
                    PrimaryButton(
                        "Continue",
                        icon: "arrow.right",
                        isDisabled: clientId.isEmpty
                    ) {
                        apiService.setClientId(clientId)
                        isSetupComplete = true
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationBarHidden(true)
        }
        .overlay(alignment: .top) {
            CopiedToast(isShowing: showingCopiedFeedback)
        }
        .animation(.easeInOut(duration: 0.2), value: showingCopiedFeedback)
    }
}


#Preview {
    OAuthSetupView(
        clientId: .constant(""),
        isSetupComplete: .constant(false),
        apiService: RedditAPIService()
    )
}