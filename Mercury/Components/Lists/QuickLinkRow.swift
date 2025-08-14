//
//  QuickLinkRow.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct QuickLinkRow: View {
    let quickLink: QuickLink
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: quickLink.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 24)
                
                Text(quickLink.rawValue)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 0) {
        ForEach(QuickLink.allCases, id: \.self) { link in
            QuickLinkRow(quickLink: link) {
                // Handle quick link tap
            }
            
            if link != QuickLink.allCases.last {
                Divider()
                    .padding(.leading, 52)
            }
        }
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .padding()
}