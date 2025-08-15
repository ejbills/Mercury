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
    let apiService: RedditAPIManager
    @State private var showingCopiedFeedback = false
    @State private var animateGradient = false
    @State private var animateIcon = false
    @State private var showContent = false
    @Namespace private var heroTransition
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Modern Hero Section
                        heroSection(geometry: geometry)
                            .padding(.bottom, 60)
                        
                        if showContent {
                            setupInstructions
                                .transition(.asymmetric(
                                    insertion: .push(from: .bottom).combined(with: .opacity),
                                    removal: .push(from: .top).combined(with: .opacity)
                                ))
                        }
                    }
                }
                .background {
                    // Dynamic background with subtle animation
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color.accentColor.opacity(0.03),
                            Color.blue.opacity(0.05)
                        ],
                        startPoint: animateGradient ? .topLeading : .bottomTrailing,
                        endPoint: animateGradient ? .bottomTrailing : .topLeading
                    )
                    .ignoresSafeArea()
                    .animation(
                        .easeInOut(duration: 8.0).repeatForever(autoreverses: true),
                        value: animateGradient
                    )
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    animateIcon = true
                }
                withAnimation(.easeOut(duration: 1.0).delay(0.8)) {
                    showContent = true
                }
                withAnimation(.easeInOut(duration: 2.0).delay(1.0)) {
                    animateGradient = true
                }
            }
        }
        .overlay(alignment: .top) {
            CopiedToast(isShowing: showingCopiedFeedback)
        }
        .animation(.easeInOut(duration: 0.2), value: showingCopiedFeedback)
    }
    
    private func heroSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 32) {
            // App Icon with Mercury theme
            VStack(spacing: 24) {
                ZStack {
                    // Background glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.orange.opacity(0.3),
                                    Color.red.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: animateIcon ? 0 : 20)
                        .scaleEffect(animateIcon ? 1.0 : 0.5)
                    
                    // Main icon container
                    ZStack {
                        // Mercury planet representation
                        Circle()
                            .fill(.orange.gradient)
                            .frame(width: 100, height: 100)
                            .overlay {
                                Circle()
                                    .fill(.orange.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .blur(radius: 2)
                            }
                            .shadow(color: .orange.opacity(0.3), radius: 20)
                        
                        // Orbital ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.8), .white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(animateIcon ? 360 : 0))
                            .animation(
                                .linear(duration: 20).repeatForever(autoreverses: false),
                                value: animateIcon
                            )
                    }
                    .scaleEffect(animateIcon ? 1.0 : 0.7)
                    .rotation3DEffect(
                        .degrees(animateIcon ? 5 : 0),
                        axis: (x: 1, y: 1, z: 0)
                    )
                }
                .matchedGeometryEffect(id: "appIcon", in: heroTransition)
                
                // App name and tagline with smooth entrance
                VStack(spacing: 12) {
                    Text("Mercury")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .scaleEffect(animateIcon ? 1.0 : 0.8)
                        .opacity(animateIcon ? 1 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6), value: animateIcon)
                    
                    Text("Fast • Elegant • Powerful")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .scaleEffect(animateIcon ? 1.0 : 0.9)
                        .opacity(animateIcon ? 1 : 0)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.8), value: animateIcon)
                    
                    Text("A beautiful Reddit client that puts speed and user experience first")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .scaleEffect(animateIcon ? 1.0 : 0.95)
                        .opacity(animateIcon ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0), value: animateIcon)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .padding(.horizontal, 32)
            .padding(.top, max(geometry.safeAreaInsets.top + 20, 60))
        }
    }
    
    private var setupInstructions: some View {
        VStack(spacing: 28) {
            // Section Title
            VStack(spacing: 8) {
                Text("Get Started")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text("Connect Mercury to Reddit with a few simple steps")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            // Modern Step Cards
            VStack(spacing: 20) {
                setupStepWithAction(
                    number: "01",
                    title: "Create Reddit App",
                    description: "Visit Reddit's app preferences to create a new application"
                ) {
                    Link("Open Reddit Apps →", destination: URL(string: "https://reddit.com/prefs/apps")!)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
                
                setupStep(
                    number: "02", 
                    title: "Configure Settings",
                    description: "Set your app type and configure the redirect URI"
                ) {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("App Type")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
                                Text("Installed App")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(.blue)
                            }
                            
                            Spacer()
                        }
                        
                        CopyableField(
                            label: "Redirect URI",
                            value: "mercury://oauth",
                            showingCopied: $showingCopiedFeedback
                        )
                    }
                }
                
                setupStep(
                    number: "03",
                    title: "Enter Client ID",
                    description: "Copy your app's Client ID and paste it below"
                ) {
                    VStack(spacing: 12) {
                        PasteableTextField(
                            placeholder: "Enter your Reddit Client ID",
                            text: $clientId
                        )
                        
                        if !clientId.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Client ID configured")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Spacer()
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Action Button
            VStack(spacing: 16) {
                PrimaryButton(
                    "Launch Mercury",
                    icon: "arrow.right",
                    isDisabled: clientId.isEmpty
                ) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        apiService.setClientId(clientId)
                        isSetupComplete = true
                    }
                }
                .padding(.horizontal, 20)
                .scaleEffect(clientId.isEmpty ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: clientId.isEmpty)
                
                Text("Your Reddit credentials are stored securely on your device")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 40)
        }
    }
    
    @ViewBuilder
    private func setupStep<Content: View>(
        number: String,
        title: String,
        description: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Step Header
            HStack(spacing: 16) {
                // Step Number
                Text(number)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                }
                
                Spacer()
            }
            
            // Step Content
            content()
                .padding(.top, 16)
                .padding(.leading, 48)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary, lineWidth: 0.5)
        )
    }
    
    @ViewBuilder
    private func setupStepWithAction(
        number: String,
        title: String,
        description: String,
        @ViewBuilder action: @escaping () -> some View
    ) -> some View {
        VStack(spacing: 0) {
            // Step Header
            HStack(spacing: 16) {
                // Step Number
                Text(number)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                }
                
                Spacer()
            }
            
            // Step Action
            HStack {
                action()
                Spacer()
            }
            .padding(.top, 12)
            .padding(.leading, 48)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary, lineWidth: 0.5)
        )
    }
}


#Preview {
    OAuthSetupView(
        clientId: .constant(""),
        isSetupComplete: .constant(false),
        apiService: RedditAPIManager()
    )
}