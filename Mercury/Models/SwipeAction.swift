import SwiftUI

struct SwipeAction {
    let type: SwipeActionType
    let action: () async -> Void
    
    var symbol: SwipeSymbol {
        SwipeSymbol(symbolName: type.systemImageName)
    }
    var color: Color { type.color }
    var displayName: String { type.displayName }
}

struct SwipeSymbol {
    let fillName: String
    let emptyName: String
    
    init(symbolName: String) {
        self.fillName = symbolName
        self.emptyName = symbolName
    }
    
    init(fillName: String, emptyName: String) {
        self.fillName = fillName
        self.emptyName = emptyName
    }
}