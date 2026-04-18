//
//  GlassInfoPill.swift
//  Conatus
//
//  Created by Seymen Özdeş on 15.04.2026.
//

import SwiftUI
import UIKit

/// Pill-shaped glass card showing a celestial icon, a bold title with trailing percentage, and a subtitle.
final class GlassInfoPill: UIView {

    // MARK: - Public

    /// Update the title, percentage, and subtitle displayed in the pill.
    func configure(title: String, percent: String, subtitle: String) {
        let attributed = NSMutableAttributedString(
            string: title,
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: UIColor.white,
            ]
        )
        attributed.append(NSAttributedString(
            string: " " + percent,
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.45),
            ]
        ))
        titleLabel.attributedText = attributed
        subtitleLabel.text = subtitle
    }

    // MARK: - Private

    private let iconView: MoonPhaseIconView = {
        let v = MoonPhaseIconView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.numberOfLines = 1
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = UIColor.white.withAlphaComponent(0.55)
        l.numberOfLines = 1
        return l
    }()

    private let textStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.alignment = .leading
        s.spacing = 1
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let innerContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 26
        v.layer.masksToBounds = true
        v.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        v.layer.borderWidth = 0.6
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
        configure(title: "New Moon", percent: "6.4%", subtitle: "New York")
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    // MARK: - Layout

    private func setupShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.cornerRadius = 26
    }

    private func setupSubviews() {
        let sheen = GlassSheenView()
        sheen.translatesAutoresizingMaskIntoConstraints = false

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.18)

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        addSubview(innerContainer)
        innerContainer.addSubview(blurView)
        blurView.contentView.addSubview(sheen)
        blurView.contentView.addSubview(iconView)
        blurView.contentView.addSubview(divider)
        blurView.contentView.addSubview(textStack)

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

            iconView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            divider.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            divider.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 28),

            textStack.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: blurView.contentView.trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
        ])
    }
}

// MARK: - Liquid Glass (iOS 26)

/// `UIViewRepresentable` bridge so `MoonPhaseIconView` can live inside SwiftUI.
private struct MoonPhaseIconRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> MoonPhaseIconView { MoonPhaseIconView() }
    func updateUIView(_ uiView: MoonPhaseIconView, context: Context) {}
}

/// SwiftUI Liquid Glass pill — same visual layout as `GlassInfoPill` but rendered
/// with the iOS 26 `.glassEffect` API so it participates in the system's real
/// Liquid Glass pipeline (refraction, specular highlights, morphing).
struct GlassInfoPillLiquidView: View {
    var title: String
    var percent: String
    var subtitle: String

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                MoonPhaseIconRepresentable()
                    .frame(width: 28, height: 28)
                    .padding(.leading, 14)

                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 1, height: 28)
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 1) {
                    (Text(title)
                        .fontWeight(.semibold)
                     + Text(" \(percent)")
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.45)))
                        .font(.system(size: 17))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.trailing, 16)
            }
            .frame(height: 52)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
        }
        .fixedSize()
    }
}

/// Builds the `UIHostingController` wrapping `GlassInfoPillLiquidView` with the
/// same hosting configuration used by `HomeGlassActionBarFactory`.
enum GlassInfoPillFactory {
    @MainActor
    static func make(
        title: String,
        percent: String,
        subtitle: String
    ) -> UIHostingController<GlassInfoPillLiquidView> {
        let host = UIHostingController(
            rootView: GlassInfoPillLiquidView(title: title, percent: percent, subtitle: subtitle)
        )
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.sizingOptions = [.intrinsicContentSize]
        host.safeAreaRegions = []
        return host
    }
}
