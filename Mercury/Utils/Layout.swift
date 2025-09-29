//
//  Layout.swift
//  Mercury
//
//  Centralized layout helpers to avoid magic numbers.
//

import UIKit
import CoreGraphics

enum Layout {
    // Standard horizontal padding used around primary content areas
    static let horizontalPadding: CGFloat = 12

    // Content width accounting for horizontal padding on both sides
    static func contentWidth() -> CGFloat {
        // Prefer a screen instance via UIWindowScene when available to avoid UIScreen.main
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return scene.screen.bounds.width - (horizontalPadding * 2)
        }

        return 375 - (horizontalPadding * 2)
    }
}

enum MediaLayout {
    /// Computes a clamped display height for media based on API-provided dimensions.
    /// - Parameters:
    ///   - dimensions: The intrinsic media size from the API (width x height).
    ///   - maxHeight: Upper bound for display height.
    ///   - fallback: Height to use when dimensions are missing.
    ///   - minHeight: Optional lower bound for display height (default 0).
    ///   - contentWidth: Available content width (defaults to Layout.contentWidth()).
    /// - Returns: A height that preserves aspect ratio and respects min/max bounds.
    static func height(
        for dimensions: CGSize?,
        maxHeight: CGFloat,
        fallback: CGFloat,
        minHeight: CGFloat = 0,
        contentWidth: CGFloat = Layout.contentWidth()
    ) -> CGFloat {
        guard let dims = dimensions, dims.width > 0, dims.height > 0 else {
            return min(maxHeight, fallback)
        }
        let aspect = dims.width / dims.height
        guard aspect > 0 else { return min(maxHeight, max(minHeight, fallback)) }
        let calculated = contentWidth / aspect
        return min(max(calculated, minHeight), maxHeight)
    }
}
