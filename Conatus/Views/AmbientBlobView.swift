//
//  AmbientBlobView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 11.04.2026.
//

import UIKit

/// Soft radial-gradient blob used as a background decoration.
final class AmbientBlobView: UIView {

    private let color: UIColor

    init(color: UIColor) {
        self.color = color
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("Use init(color:)") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let colors = [
            color.cgColor,
            color.withAlphaComponent(0).cgColor,
        ] as CFArray
        let locations: [CGFloat] = [0, 1]
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius  = max(rect.width, rect.height) / 2
        ctx.drawRadialGradient(
            gradient,
            startCenter: center, startRadius: 0,
            endCenter: center,   endRadius: radius,
            options: []
        )
    }
}
