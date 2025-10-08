import Foundation
import Defaults

struct StoredAccount: Codable, Defaults.Serializable, Identifiable, Equatable {
    var id: String { username.lowercased() }
    let username: String
    var refreshToken: String
    var lastUpdated: Date
    // Optional to maintain backward compatibility with previously stored data
    var clientId: String? = nil
}
