//
//  AnimatedGifView.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI
import SwiftyGif
import UIKit

struct AnimatedGifView: UIViewRepresentable {
    let url: URL
    let contentMode: UIView.ContentMode
    let cornerRadius: CGFloat
    @State private var gifImageView = UIImageView()
    @State private var isLoading = true
    @State private var onLoadingChange: ((Bool) -> Void)?
    
    init(url: URL, contentMode: UIView.ContentMode = .scaleAspectFit, cornerRadius: CGFloat = 12, onLoadingChange: ((Bool) -> Void)? = nil) {
        self.url = url
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.onLoadingChange = onLoadingChange
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.systemGray5
        containerView.layer.cornerRadius = cornerRadius
        containerView.layer.masksToBounds = true
        
        gifImageView.contentMode = contentMode
        gifImageView.translatesAutoresizingMaskIntoConstraints = false
        gifImageView.backgroundColor = UIColor.clear
        
        containerView.addSubview(gifImageView)
        
        NSLayoutConstraint.activate([
            gifImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            gifImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            gifImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            gifImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        loadGif()
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update if needed
    }
    
    private func loadGif() {
        Task {
            do {
                onLoadingChange?(true)
                let (data, _) = try await URLSession.shared.data(from: url)
                
                await MainActor.run {
                    do {
                        let gif = try UIImage(gifData: data)
                        gifImageView.setGifImage(gif, loopCount: -1) // Loop indefinitely
                        onLoadingChange?(false)
                    } catch {
                        // Fallback to static image if GIF loading fails
                        gifImageView.image = UIImage(data: data)
                        onLoadingChange?(false)
                        // Failed to load GIF, showing static image instead
                    }
                }
            } catch {
                await MainActor.run {
                    gifImageView.image = UIImage(systemName: "photo")?.withTintColor(.systemGray3, renderingMode: .alwaysOriginal)
                    onLoadingChange?(false)
                    // Failed to load GIF data
                }
            }
        }
    }
}

struct AnimatedGifCard: View {
    let url: URL
    let cornerRadius: CGFloat
    @State private var isLoading = true
    @State private var isVisible = false
    
    init(url: URL, cornerRadius: CGFloat = 12) {
        self.url = url
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        ZStack {
            AnimatedGifView(
                url: url,
                contentMode: .scaleAspectFit,
                cornerRadius: cornerRadius
            ) { loading in
                isLoading = loading
                if !loading && !isVisible {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isVisible = true
                    }
                }
            }
            .frame(maxWidth: .infinity) // Prevent horizontal overflow
            .frame(maxHeight: 600) // Allow natural sizing with reasonable max
            .background(.quaternary.opacity(0.1)) // Subtle background
            .clipped() // Prevent overflow
            .opacity(isVisible ? 1 : 0)
            
            // Loading indicator overlay
            if isLoading {
                Rectangle()
                    .fill(.quaternary.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 300) // Default height during loading
                    .overlay {
                        ProgressView()
                            .scaleEffect(1.2)
                    }
            }
            
            // GIF badge
            VStack {
                HStack {
                    Spacer()
                    Text("GIF")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
                        .opacity(isVisible ? 1 : 0)
                }
                .padding(10)
                Spacer()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear {
            if !isLoading && !isVisible {
                withAnimation(.easeOut(duration: 0.3)) {
                    isVisible = true
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            if let url = URL(string: "https://i.imgur.com/example.gif") {
                AnimatedGifCard(url: url)
                    .frame(height: 300)
            }
        }
        .padding()
    }
}