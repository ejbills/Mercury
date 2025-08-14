//
//  SectionHeader.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct SectionHeader: View {
    let icon: String
    let title: String
    let color: Color
    
    init(icon: String, title: String, color: Color = Color.accentColor) {
        self.icon = icon
        self.title = title
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        SectionHeader(icon: "1.circle.fill", title: "Create Reddit App")
        SectionHeader(icon: "key.fill", title: "Client ID", color: .blue)
        SectionHeader(icon: "checkmark.circle.fill", title: "Success", color: .green)
    }
    .padding()
}