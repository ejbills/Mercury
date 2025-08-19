//
//  GiphyService.swift
//  Mercury
//
//  Created by AI Assistant on 8/18/25.
//

import Foundation

struct GiphyService {
    private static let baseURL = "https://api.giphy.com/v1/gifs/"
    
    private static var apiKey: String? {
        let key = Secrets.giphyAPIKey
        return key.isEmpty ? nil : key
    }
    
    static func resolveGiphyURL(from redditFormat: String) async -> String? {
        let result = await resolveGiphyMedia(from: redditFormat)
        return result?.url
    }
    
    static func resolveGiphyMedia(from redditFormat: String) async -> GiphyMedia? {
        guard let apiKey = apiKey else {
            return nil
        }
        
        // Extract Giphy ID from Reddit's format
        let giphyID = extractGiphyID(from: redditFormat)
        guard !giphyID.isEmpty else { return nil }
        
        // Construct API URL
        let urlString = "\(baseURL)\(giphyID)?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GiphyResponse.self, from: data)
            
            let image = response.data.images.downsized
            let width = Double(image.width) ?? 400
            let height = Double(image.height) ?? 300
            
            return GiphyMedia(
                url: image.url,
                dimensions: CGSize(width: width, height: height)
            )
        } catch {
            return nil
        }
    }
    
    private static func extractGiphyID(from redditFormat: String) -> String {
        // Handle URL-encoded format: giphy%7CBNkHCHnAsZwRi or giphy%7C7jjMlMNaZrJ1m%7Cdownsized
        let decoded = redditFormat.removingPercentEncoding ?? redditFormat
        
        // Handle both | and %7C separators
        var giphyID = ""
        
        if decoded.hasPrefix("giphy|") {
            let withoutPrefix = String(decoded.dropFirst(6)) // Remove "giphy|"
            // Split by | to get just the ID part (before any format suffix like "downsized")
            giphyID = withoutPrefix.components(separatedBy: "|").first ?? withoutPrefix
        } else if decoded.hasPrefix("giphy%7C") {
            let withoutPrefix = String(decoded.dropFirst(8)) // Remove "giphy%7C"
            // Split by %7C to get just the ID part
            giphyID = withoutPrefix.components(separatedBy: "%7C").first ?? withoutPrefix
        } else if redditFormat.hasPrefix("giphy%7C") {
            let withoutPrefix = String(redditFormat.dropFirst(8)) // Remove "giphy%7C"
            // Split by %7C to get just the ID part
            giphyID = withoutPrefix.components(separatedBy: "%7C").first ?? withoutPrefix
        } else {
            giphyID = redditFormat
        }
        
        return giphyID
    }
}

// MARK: - Giphy Media Result
struct GiphyMedia {
    let url: String
    let dimensions: CGSize
}

// MARK: - Giphy API Models
struct GiphyResponse: Codable {
    let data: GiphyData
}

struct GiphyData: Codable {
    let id: String
    let images: GiphyImages
}

struct GiphyImages: Codable {
    let downsized: GiphyImage
    let downsizedMedium: GiphyImage
    let original: GiphyImage
    
    enum CodingKeys: String, CodingKey {
        case downsized
        case downsizedMedium = "downsized_medium"
        case original
    }
}

struct GiphyImage: Codable {
    let url: String
    let width: String
    let height: String
}
