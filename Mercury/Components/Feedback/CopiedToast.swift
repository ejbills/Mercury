//
//  CopiedToast.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct CopiedToast: View {
    let isShowing: Bool
    
    var body: some View {
        if isShowing {
            Text("Copied!")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 60)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

#Preview {
    VStack {
        CopiedToast(isShowing: true)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.blue.gradient)
}