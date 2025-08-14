//
//  StatusIcon.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import SwiftUI

struct StatusIcon: View {
    let status: RedditAPIService.APIStatus
    
    var body: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 80, height: 80)
            
            Image(systemName: statusIconName)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .unknown:
            return .gray
        case .validating:
            return .blue
        case .valid:
            return .green
        case .invalid, .networkError:
            return .red
        }
    }
    
    private var statusIconName: String {
        switch status {
        case .unknown:
            return "questionmark"
        case .validating:
            return "clock"
        case .valid:
            return "checkmark"
        case .invalid, .networkError:
            return "xmark"
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        StatusIcon(status: .unknown)
        StatusIcon(status: .validating)
        StatusIcon(status: .valid)
        StatusIcon(status: .invalid)
    }
    .padding()
}