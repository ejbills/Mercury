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
    }
    
    private func loadGif() {
        Task {
            do {
                onLoadingChange?(true)
                let (data, _) = try await URLSession.shared.data(from: url)
                
                await MainActor.run {
                    do {
                        let gif = try UIImage(gifData: data)
                        gifImageView.setGifImage(gif, loopCount: -1)
                        onLoadingChange?(false)
                    } catch {
                        gifImageView.image = UIImage(data: data)
                        onLoadingChange?(false)
                    }
                }
            } catch {
                await MainActor.run {
                    gifImageView.image = UIImage(systemName: "photo")?.withTintColor(.systemGray3, renderingMode: .alwaysOriginal)
                    onLoadingChange?(false)
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
    let fixedHeight: CGFloat?
    
    init(url: URL, cornerRadius: CGFloat = 12, apiDimensions: CGSize? = nil, maxHeight: CGFloat = 600, fixedHeight: CGFloat? = nil) {
        self.url = url
        self.cornerRadius = cornerRadius
        self.apiDimensions = apiDimensions
        self.maxHeight = maxHeight
        self.fixedHeight = fixedHeight
    }
    
    private var displayHeight: CGFloat {
        if let fixedHeight = fixedHeight { return fixedHeight }
        return MediaLayout.height(for: apiDimensions, maxHeight: maxHeight, fallback: 300)
    }
    
    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(maxWidth: .infinity)
            .frame(height: displayHeight)
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
