//
//  CommentThreading.swift
//  Mercury
//
//  Created by Ethan Bills on 8/15/25.
//

import SwiftUI

enum ThreadLineKind {
    case straight
    case curve
    case straightCurve
    case none
    
    var child: ThreadLineKind {
        switch self {
        case .straight, .straightCurve:
            return .straight
        case .curve:
            return .none
        case .none:
            return .none
        }
    }
}

struct ThreadLine: View {
    let kind: ThreadLineKind
    let color: Color
    let isLast: Bool
    
    var body: some View {
        switch kind {
        case .straight:
            Rectangle()
                .fill(color)
                .frame(width: 1.5)
        case .curve:
            curveShape
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        case .straightCurve:
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(color)
                    .frame(width: 1.5)
                
                if isLast {
                    VStack(spacing: 0) {
                        Spacer()
                        curveShape
                            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .frame(height: 16)
                            .offset(y: -8)
                    }
                }
            }
        case .none:
            Color.clear.frame(width: 1.5)
        }
    }
    
    private var curveShape: some Shape {
        CurveShape()
    }
}

struct CurveShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let startX: CGFloat = 0.75 // Align with thread line width
            let startY = rect.minY
            let endX = rect.width - 2
            let endY = rect.height * 0.7
            
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: startX, y: endY - 4))
            path.addQuadCurve(
                to: CGPoint(x: endX, y: endY),
                control: CGPoint(x: startX, y: endY)
            )
        }
    }
}

struct CommentThreadLines: View {
    let threadKinds: [ThreadLineKind]
    let colors: [Color]
    let isLastInThread: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            ForEach(Array(threadKinds.enumerated()), id: \.offset) { index, kind in
                ThreadLine(
                    kind: kind,
                    color: colors[index % colors.count].opacity(0.8),
                    isLast: isLastInThread && index == threadKinds.count - 1
                )
                .frame(width: 12, alignment: .leading)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .padding(.trailing, 4)
    }
}

extension RedditComment {
    func generateThreadKinds(isLast: Bool, parentKinds: [ThreadLineKind] = []) -> [ThreadLineKind] {
        if depth == 0 {
            return []
        }
        
        // For depth 1+, inherit parent's continued lines and add this comment's line
        var kinds: [ThreadLineKind] = []
        
        // Add continued lines from ancestors
        for parentKind in parentKinds {
            kinds.append(parentKind.child)
        }
        
        // Add this comment's line type
        let newKind: ThreadLineKind = isLast ? .curve : .straightCurve
        kinds.append(newKind)
        
        return kinds
    }
    
    // Helper to generate kinds with proper parent context
    func generateThreadKinds(isLast: Bool, ancestorKinds: [ThreadLineKind]) -> [ThreadLineKind] {
        return generateThreadKinds(isLast: isLast, parentKinds: ancestorKinds)
    }
}