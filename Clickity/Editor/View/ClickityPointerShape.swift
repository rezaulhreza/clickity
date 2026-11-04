//
//  ClickityPointerShape.swift
//  Clickity
//

import SwiftUI

/// The pointer of Clickity's icon, fitted to its frame, for the cursor style tile.
nonisolated struct ClickityPointerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let outline = OverlayImages.clickityPointer
        let width = outline.map(\.x).max() ?? 1
        let height = outline.map(\.y).max() ?? 1
        let scale = min(rect.width / width, rect.height / height)
        var path = Path()
        path.addLines(outline.map { CGPoint(x: rect.minX + $0.x * scale, y: rect.minY + $0.y * scale) })
        path.closeSubpath()
        return path
    }
}
