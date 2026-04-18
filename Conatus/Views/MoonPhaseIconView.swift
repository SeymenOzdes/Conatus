//
//  MoonPhaseIconView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 15.04.2026.
//

import UIKit

/// Celestial glyph with six dotted radial rays around a tilted teardrop silhouette.
final class MoonPhaseIconView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2

        drawDottedRays(in: ctx, center: center, outerRadius: outerRadius)
        drawTeardrop(in: ctx, center: center, radius: outerRadius * 0.42)
    }

    // MARK: - Helpers

    private func drawDottedRays(in ctx: CGContext, center: CGPoint, outerRadius: CGFloat) {
        let rayCount = 6
        let dotsPerRay = 4
        let innerFraction: CGFloat = 0.45
        let outerFraction: CGFloat = 0.98
        let dotRadius: CGFloat = max(outerRadius * 0.045, 0.8)
        
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
        
        for rayIndex in 0..<rayCount {
            let angle = (CGFloat(rayIndex) / CGFloat(rayCount)) * 2 * .pi - .pi / 2
            for dotIndex in 0..<dotsPerRay {
                let t = CGFloat(dotIndex) / CGFloat(dotsPerRay - 1)
                let distance = outerRadius * (innerFraction + (outerFraction - innerFraction) * t)
                let x = center.x + cos(angle) * distance
                let y = center.y + sin(angle) * distance
                ctx.fillEllipse(
                    in: CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                )
            }
        }
    }

    private func drawTeardrop(in ctx: CGContext, center: CGPoint, radius: CGFloat) {
        let path = UIBezierPath()
        let tipAngle: CGFloat = -.pi / 2 + .pi / 7 // slight clockwise tilt
        let tip = CGPoint(
            x: center.x + cos(tipAngle) * radius * 1.05,
            y: center.y + sin(tipAngle) * radius * 1.05
        )

        let left = CGPoint(x: center.x - radius * 0.95, y: center.y + radius * 0.25)
        let right = CGPoint(x: center.x + radius * 0.95, y: center.y + radius * 0.25)
        let bottom = CGPoint(x: center.x + radius * 0.1, y: center.y + radius * 0.95)

        path.move(to: tip)
        path.addQuadCurve(
            to: left,
            controlPoint: CGPoint(x: center.x - radius * 1.1, y: center.y - radius * 0.6)
        )
        path.addQuadCurve(
            to: bottom,
            controlPoint: CGPoint(x: center.x - radius * 0.9, y: center.y + radius * 1.0)
        )
        path.addQuadCurve(
            to: right,
            controlPoint: CGPoint(x: center.x + radius * 1.05, y: center.y + radius * 0.95)
        )
        path.addQuadCurve(
            to: tip,
            controlPoint: CGPoint(x: center.x + radius * 1.15, y: center.y - radius * 0.45)
        )
        path.close()

        ctx.setFillColor(UIColor.white.withAlphaComponent(0.28).cgColor)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
    }
}
