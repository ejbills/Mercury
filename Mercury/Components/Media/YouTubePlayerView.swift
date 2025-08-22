import SwiftUI
import YouTubePlayerKit

struct YouTubeEmbedView: View {
    let url: String
    let youTubePlayer: YouTubePlayer
    
    init(url: String) {
        self.url = url
        self.youTubePlayer = YouTubePlayer(stringLiteral: url)
    }
    
    var body: some View {
        YouTubePlayerView(youTubePlayer) { state in
            switch state {
            case .idle:
                ProgressView()
                    .frame(height: 250)
            case .ready:
                EmptyView()
            case .error(let error):
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.red)
                    Text("YouTube Error")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 250)
            }
        }
        .frame(height: 250)
        .cornerRadius(12)
    }
}