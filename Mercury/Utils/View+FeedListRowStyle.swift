import SwiftUI

extension View {
    func feedListRowStyle() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
    
    func feedListBaseStyle(rowSpacing: CGFloat) -> some View {
        self
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowSpacing(rowSpacing)
            .environment(\.defaultMinListRowHeight, 0)
    }
}
