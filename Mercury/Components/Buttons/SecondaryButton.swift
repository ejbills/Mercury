//
//  SecondaryButton.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let isDisabled: Bool
    let action: () -> Void
    
    init(
        _ title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.headline)
                }
                
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(isDisabled)
    }
}

#Preview {
    VStack(spacing: 16) {
        SecondaryButton("Change Credentials", icon: "pencil") {}
        SecondaryButton("Cancel") {}
    }
    .padding()
}