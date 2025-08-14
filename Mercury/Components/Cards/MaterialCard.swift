//
//  MaterialCard.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct MaterialCard<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    MaterialCard {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card Title")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Card content goes here with some description text that explains what this card is about.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}