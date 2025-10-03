import SwiftUI
import Defaults
import UIKit

struct SerializableColor: Codable, Defaults.Serializable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 1
        var g: CGFloat = 1
        var b: CGFloat = 1
        var a: CGFloat = 1

        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            self.init(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
        } else {
            let cgColor = uiColor.cgColor
            let converted = cgColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
            let components = converted?.components ?? cgColor.components ?? [1, 1, 1, 1]
            let normalized = components + Array(repeating: 1.0, count: max(0, 4 - components.count))
            self.init(red: Double(normalized[0]),
                      green: Double(normalized[1]),
                      blue: Double(normalized[2]),
                      alpha: Double(normalized[3]))
        }
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
