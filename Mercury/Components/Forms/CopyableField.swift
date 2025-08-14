//
//  CopyableField.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct CopyableField: View {
    let label: String
    let value: String
    @Binding var showingCopied: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            Button {
                UIPasteboard.general.string = value
                showingCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showingCopied = false
                }
            } label: {
                HStack {
                    Text(value)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    CopyableField(
        label: "Redirect URI",
        value: "apolled://oauth",
        showingCopied: .constant(false)
    )
    .padding()
}