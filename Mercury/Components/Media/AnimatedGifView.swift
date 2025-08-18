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
    let apiDimensions: CGSize?
    let maxHeight: CGFloat
    
    init(url: URL, cornerRadius: CGFloat = 12, apiDimensions: CGSize? = nil, maxHeight: CGFloat = 600) {
        self.url = url
        self.cornerRadius = cornerRadius
        self.apiDimensions = apiDimensions
        self.maxHeight = maxHeight
    }
    
    private var displayHeight: CGFloat {
        guard let apiDimensions = apiDimensions else { 
            return min(maxHeight, 300) // Fallback height
        }
        
        let screenWidth = UIScreen.main.bounds.width - 24 // Account for padding
        let aspectRatio = apiDimensions.width / apiDimensions.height
        let calculatedHeight = screenWidth / aspectRatio
        return min(calculatedHeight, maxHeight) // Respect max height cap
    }
    
    var body: some View {
        // FIXED FRAME CONTAINER - NEVER CHANGES SIZE
        Rectangle()
            .fill(.clear)
            .frame(maxWidth: .infinity)
            .frame(height: displayHeight) // Use calculated height from API dimensions
            .overlay {
                ZStack {
                    AnimatedGifView(
                        url: url,
                        contentMode: .scaleAspectFill,
                        cornerRadius: cornerRadius
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: displayHeight)
                    .clipped()
                    
                    // GIF badge overlay
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
                        }
                        .padding(10)
                        Spacer()
                    }
                }
            }
            .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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