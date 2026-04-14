//
//  HomeView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 11.04.2026.
//

import UIKit

/// Root view for the home screen. Owns the gradient background, ambient blobs, and search bar layout.
final class HomeView: UIView {

    // MARK: - Public

    let searchBar = GlassSearchBar()

    // MARK: - Private

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.04, green: 0.04, blue: 0.20, alpha: 1).cgColor,
            UIColor(red: 0.12, green: 0.04, blue: 0.30, alpha: 1).cgColor,
            UIColor(red: 0.22, green: 0.06, blue: 0.22, alpha: 1).cgColor,
        ]
        layer.locations = [0.0, 0.55, 1.0]
        layer.startPoint = CGPoint(x: 0.2, y: 0)
        layer.endPoint   = CGPoint(x: 0.8, y: 1)
        return layer
    }()

    private let blobA = AmbientBlobView(color: UIColor(red: 0.40, green: 0.10, blue: 0.80, alpha: 0.30))
    private let blobB = AmbientBlobView(color: UIColor(red: 0.10, green: 0.30, blue: 0.80, alpha: 0.20))

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBackground()
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        blobA.frame = CGRect(x: -60, y: 100, width: 320, height: 320)
        blobB.frame = CGRect(x: bounds.width - 220, y: bounds.height - 440, width: 280, height: 280)
    }

    // MARK: - Setup

    private func setupBackground() {
        layer.insertSublayer(gradientLayer, at: 0)
        insertSubview(blobA, at: 1)
        insertSubview(blobB, at: 2)
    }

    private func setupLayout() {
        addSubview(searchBar)
        searchBar.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            searchBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            searchBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            searchBar.heightAnchor.constraint(equalToConstant: 52),
        ])
    }
}
