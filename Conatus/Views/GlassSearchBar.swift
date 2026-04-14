//
//  GlassSearchBar.swift
//  Conatus
//
//  Created by Seymen Özdeş on 11.04.2026.
//

import UIKit

/// Pill-shaped iOS 26 Glass-style search bar built from UIVisualEffectView.
final class GlassSearchBar: UIView {

    // MARK: - Public

    let searchField: UITextField = {
        let tf = UITextField()
        tf.font = .systemFont(ofSize: 17, weight: .regular)
        tf.textColor = .white
        tf.tintColor = .white
        tf.borderStyle = .none
        tf.returnKeyType = .search
        tf.keyboardAppearance = .dark
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.attributedPlaceholder = NSAttributedString(
            string: "Search",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.40)]
        )
        return tf
    }()

    // MARK: - Private

    private let searchIcon: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let iv = UIImageView(image: UIImage(systemName: "magnifyingglass", withConfiguration: config))
        iv.tintColor = UIColor.white.withAlphaComponent(0.55)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let innerContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius  = 26
        v.layer.masksToBounds = true
        v.layer.borderColor   = UIColor.white.withAlphaComponent(0.22).cgColor
        v.layer.borderWidth   = 0.6
        return v
    }()

    private let blurView: UIVisualEffectView = {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setupShadow()
        setupSubviews()
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    // MARK: - Setup

    private func setupShadow() {
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius  = 20
        layer.shadowOffset  = CGSize(width: 0, height: 8)
        layer.cornerRadius  = 26
    }

    private func setupSubviews() {
        let sheen = GlassSheenView()
        sheen.translatesAutoresizingMaskIntoConstraints = false

        addSubview(innerContainer)
        innerContainer.addSubview(blurView)
        blurView.contentView.addSubview(sheen)
        blurView.contentView.addSubview(searchIcon)
        blurView.contentView.addSubview(searchField)

        NSLayoutConstraint.activate([
            innerContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            innerContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            innerContainer.topAnchor.constraint(equalTo: topAnchor),
            innerContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            blurView.leadingAnchor.constraint(equalTo: innerContainer.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: innerContainer.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: innerContainer.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: innerContainer.bottomAnchor),

            sheen.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            sheen.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            sheen.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            sheen.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),

            searchIcon.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 18),
            searchIcon.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 18),
            searchIcon.heightAnchor.constraint(equalToConstant: 18),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -18),
            searchField.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            searchField.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
        ])
    }
}
