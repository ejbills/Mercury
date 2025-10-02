import Foundation

struct LinkFlair: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let backgroundColor: String?
    let textColor: String?
    let textEditable: Bool?
    let modOnly: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case backgroundColor = "background_color"
        case textColor = "text_color"
        case textEditable = "text_editable"
        case modOnly = "mod_only"
    }
}
