//
//  RootViewController.swift
//  Conatus
//
//  Created by Seymen Özdeş on 22.04.2026.
//

import SwiftUI
import UIKit

final class RootViewController: UIViewController {

    // MARK: - Children

    private let detailPresenter = SpotDetailPresenter()
    private lazy var homeVC = HomeViewController()
    private lazy var spotVC = SpotViewController(detailPresenter: detailPresenter)
    private var currentChild: UIViewController?

    // MARK: - Tab Bar

    private lazy var tabBarHost: UIHostingController<GlassTabBarView> = {
        var tabBarView = GlassTabBarView()
        tabBarView.onTabSelected = { [weak self] tab in
            self?.show(tab: tab)
        }
        let host = UIHostingController(rootView: tabBarView)
        host.view.backgroundColor = .clear
        return host
    }()

    // MARK: - Detail Sheet

    private lazy var detailHost: UIHostingController<SpotDetailSheetContainer> = {
        let root = SpotDetailSheetContainer(
            presenter: detailPresenter,
            onClose: { [weak self] in self?.dismissDetail() },
            onExpand: { [weak self] in self?.presentExpandedDetail() }
        )
        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        host.sizingOptions = .intrinsicContentSize
        return host
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        installTabBar()
        installDetailSheet()
        show(tab: .home)
    }

    // MARK: - Tab Switching

    private func show(tab: CustomTab) {
        let target: UIViewController = (tab == .spots) ? spotVC : homeVC

        if tab != .spots {
            dismissDetail()
        }

        // Ensure the target is attached lazily when first needed.
        ensureAttached(target)
        target.loadViewIfNeeded()

        if let current = currentChild {
            // If we already have a current child, and it's different, hide it and show the target.
            guard current !== target else { return }
            current.view.isHidden = true
            target.view.isHidden = false
            currentChild = target
        } else {
            // First time: hide the other controller if it's attached, show target.
            let other = (target === homeVC) ? spotVC : homeVC
            if other.view.superview != nil {
                other.view.isHidden = true
            }
            target.view.isHidden = false
            currentChild = target
        }
    }

    /// Ensures the given child controller's view is attached and constrained below the tab bar.
    private func ensureAttached(_ vc: UIViewController) {
        // If already attached to this parent and has a superview, do nothing.
        if vc.parent === self, vc.view.superview != nil { return }

        // If not already a child of this container, add it.
        if vc.parent !== self { addChild(vc) }

        vc.view.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(vc.view, belowSubview: tabBarHost.view)
        NSLayoutConstraint.activate([
            vc.view.topAnchor.constraint(equalTo: view.topAnchor),
            vc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Call didMove only the first time we add as child.
        if vc.parent !== self { vc.didMove(toParent: self) }
    }

    // MARK: - Layout

    private func installTabBar() {
        addChild(tabBarHost)
        let bar = tabBarHost.view!
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            bar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
        tabBarHost.didMove(toParent: self)
    }

    private func installDetailSheet() {
        addChild(detailHost)
        let sheet = detailHost.view!
        sheet.translatesAutoresizingMaskIntoConstraints = false
        // Insert above the tab bar so the sheet floats over it in z-order.
        view.addSubview(sheet)
        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: tabBarHost.view.topAnchor, constant: -8),
        ])
        detailHost.didMove(toParent: self)
    }

    // MARK: - Actions

    private func dismissDetail() {
        guard detailPresenter.selectedSpot != nil else { return }
        if presentedViewController != nil {
            dismiss(animated: true)
        }
        detailPresenter.selectedSpot = nil
        spotVC.deselectAllSpots()
    }

    private func presentExpandedDetail() {
        guard let spot = detailPresenter.selectedSpot,
              presentedViewController == nil else { return }

        let host = UIHostingController(
            rootView: SpotDetailView(
                spot: spot,
                onClose: { [weak self] in self?.dismiss(animated: true) }
            )
        )
        host.modalPresentationStyle = .fullScreen
        present(host, animated: true)
    }
}
