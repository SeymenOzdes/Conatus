//
//  GlassSheenView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 11.04.2026.
//

import UIKit

/// Subtle top-lit gradient drawn over the blur layer to simulate a glass sheen.
final class GlassSheenView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let colors = [
            UIColor.white.withAlphaComponent(0.14).cgColor,
            UIColor.white.withAlphaComponent(0.00).cgColor,
        ] as CFArray
        let locations: [CGFloat] = [0, 1]
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) else { return }
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end:   CGPoint(x: rect.midX, y: rect.midY),
            options: []
        )
    }
}
