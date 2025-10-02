import Foundation

struct PostRequirements: Codable {
    let isFlairRequired: Bool?

    enum CodingKeys: String, CodingKey {
        case isFlairRequired = "is_flair_required"
    }
}

