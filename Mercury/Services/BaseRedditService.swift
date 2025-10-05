import Foundation

/// Base class providing common functionality for all Reddit services
class BaseRedditService {
    let baseURL = "https://oauth.reddit.com"
    
    weak var authService: AuthenticationService?
    
    init(authService: AuthenticationService) {
        self.authService = authService
    }
    
    /// Creates a URLRequest with common headers
    func createRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let accessToken = authService?.accessToken {
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    /// Creates a POST URLRequest with common headers
    func createPOSTRequest(url: URL) -> URLRequest {
        var request = createRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    /// Validates that we have a valid access token
    func validateAccessToken() throws {
        guard authService?.accessToken != nil else {
            throw APIError.missingAccessToken
        }
    }
    
    private static let defaultSuccessStatusCodes = Set(200..<300)

    /// Handles common HTTP response validation
    func validateResponse(_ response: HTTPURLResponse, allowedStatusCodes: [Int] = []) throws {
        let allowed = allowedStatusCodes.isEmpty ? Self.defaultSuccessStatusCodes : Set(allowedStatusCodes)
        guard allowed.contains(response.statusCode) else {
            switch response.statusCode {
            case 401:
                throw APIError.invalidToken
            case 403:
                throw APIError.insufficientScope
            case 404:
                throw APIError.notFound
            default:
                throw APIError.serverError(response.statusCode)
            }
        }
    }
}

/// Common API errors used across all services
enum APIError: LocalizedError {
    case missingAccessToken
    case networkError
    case invalidToken
    case insufficientScope
    case parseError
    case serverError(Int)
    case notFound
    case subredditNotFound
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "Missing access token"
        case .networkError:
            return "Network error - check your connection"
        case .invalidToken:
            return "Access token expired or invalid"
        case .insufficientScope:
            return "Insufficient permissions - please re-authenticate"
        case .parseError:
            return "Failed to parse response data"
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        case .notFound:
            return "Resource not found"
        case .subredditNotFound:
            return "Subreddit not found or is private"
        case .userNotFound:
            return "User not found or profile is private"
        }
    }
}

enum VoteDirection: Int {
    case downvote = -1
    case neutral = 0
    case upvote = 1
}
