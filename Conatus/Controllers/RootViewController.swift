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
    private let addSpotPresenter = AddSpotPresenter()
    private let startSessionPresenter = StartSessionPresenter()
    private let homeToastController = HomeToastController()
    private lazy var homeVC = HomeViewController(
        startSessionPresenter: startSessionPresenter,
        toastController: homeToastController,
        detailPresenter: detailPresenter
    )
    private lazy var spotVC = SpotViewController(
        detailPresenter: detailPresenter,
        addSpotPresenter: addSpotPresenter
    )
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

    private lazy var addSheetHost: UIHostingController<AddSpotSheetContainer> = {
        let root = AddSpotSheetContainer(
            presenter: addSpotPresenter,
            onSave: { [weak self] userSpot in self?.handleAddSpotSave(userSpot) },
            onClose: { [weak self] in self?.addSpotPresenter.dismiss() }
        )
        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        host.sizingOptions = .intrinsicContentSize
        return host
    }()

    private lazy var startSessionBackdropHost: UIHostingController<StartSessionBackdrop> = {
        let root = StartSessionBackdrop(
            presenter: startSessionPresenter,
            onTap: { [weak self] in self?.startSessionPresenter.dismiss() }
        )
        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        return host
    }()

    private lazy var startSessionSheetHost: UIHostingController<StartSessionSheetContainer> = {
        let root = StartSessionSheetContainer(
            presenter: startSessionPresenter,
            pinnedSpots: { Self.resolvePinnedSpots() },
            onSave: { [weak self] session in self?.handleStartSessionSave(session) },
            onClose: { [weak self] in self?.startSessionPresenter.dismiss() }
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
        installAddSheet()
        installStartSessionBackdrop()
        installStartSessionSheet()
        wireAddSpotPresenter()
        wireStartSessionPresenter()
        show(tab: .home)
    }

    private func wireAddSpotPresenter() {
        // Opening the add sheet collapses any open detail or session sheet so they don't overlap.
        addSpotPresenter.onPresent = { [weak self] in
            self?.dismissDetail()
            self?.startSessionPresenter.dismiss()
        }
    }

    private func wireStartSessionPresenter() {
        // Opening the session sheet collapses the detail and add sheets, enables
        // the backdrop host so it can catch tap-to-dismiss, and hides the tab bar
        // so the sheet visually replaces it from the bottom of the screen.
        startSessionPresenter.onPresent = { [weak self] in
            guard let self else { return }
            self.dismissDetail()
            self.addSpotPresenter.dismiss()
            self.startSessionBackdropHost.view.isUserInteractionEnabled = true
            self.setTabBarHidden(true, animated: true)
        }
        startSessionPresenter.onDismiss = { [weak self] in
            guard let self else { return }
            self.startSessionBackdropHost.view.isUserInteractionEnabled = false
            self.setTabBarHidden(false, animated: true)
        }
    }

    private func setTabBarHidden(_ hidden: Bool, animated: Bool) {
        let bar = tabBarHost.view!
        let targetAlpha: CGFloat = hidden ? 0 : 1
        guard bar.alpha != targetAlpha else { return }
        let apply = {
            bar.alpha = targetAlpha
        }
        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut], animations: apply)
        } else {
            apply()
        }
        bar.isUserInteractionEnabled = !hidden
    }

    // MARK: - Tab Switching

    private func show(tab: CustomTab) {
        let target: UIViewController = (tab == .spots) ? spotVC : homeVC

        if tab != .spots {
            dismissDetail()
            addSpotPresenter.dismiss()
        }
        if tab != .home {
            startSessionPresenter.dismiss()
        }

        // Ensure the target is attached lazily when first needed.
        ensureAttached(target)
        target.loadViewIfNeeded()
        target.view.isHidden = false

        if let current = currentChild, current !== target {
            current.view.isHidden = true
        }
        currentChild = target
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

    private func installAddSheet() {
        addChild(addSheetHost)
        let sheet = addSheetHost.view!
        sheet.translatesAutoresizingMaskIntoConstraints = false
        // Insert above the detail sheet — when both could conceptually appear, the add sheet wins.
        view.addSubview(sheet)
        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: tabBarHost.view.topAnchor, constant: -8),
        ])
        addSheetHost.didMove(toParent: self)
    }

    private func installStartSessionBackdrop() {
        addChild(startSessionBackdropHost)
        let backdrop = startSessionBackdropHost.view!
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        // Sits above tab bar and tab content but below the session sheet,
        // so it dims the entire screen behind the sheet.
        view.addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        // The host's full-screen UIView would otherwise swallow every tap
        // (the inner SwiftUI `.allowsHitTesting(false)` doesn't reach UIKit's
        // hitTest). Toggled on by `onPresent`, off by `onDismiss`.
        backdrop.isUserInteractionEnabled = false
        startSessionBackdropHost.didMove(toParent: self)
    }

    private func installStartSessionSheet() {
        addChild(startSessionSheetHost)
        let sheet = startSessionSheetHost.view!
        sheet.translatesAutoresizingMaskIntoConstraints = false
        // Sits above the add sheet in z-order — only one is ever visible at a time
        // due to the mutual-exclusion wiring on the presenters. Anchored to the
        // bottom safe-area edge so the sheet rises from the screen bottom; the
        // tab bar is hidden while the sheet is presented (see wireStartSessionPresenter).
        view.addSubview(sheet)
        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        startSessionSheetHost.didMove(toParent: self)
    }

    // MARK: - Actions

    private func dismissDetail() {
        guard detailPresenter.selectedSpot != nil else { return }
        if presentedViewController != nil {
            dismiss(animated: true)
        }
        detailPresenter.select(nil)
        spotVC.deselectAllSpots()
    }

    private func handleAddSpotSave(_ userSpot: UserSpot) {
        UserSpotsRepository.shared.add(userSpot)
        addSpotPresenter.dismiss()
    }

    private func handleStartSessionSave(_ session: UserSession) {
        UserSessionsRepository.shared.add(session)
        startSessionPresenter.dismiss()
        homeToastController.show("Session saved")
    }

    private static func resolvePinnedSpots() -> [Spot] {
        let prefs = UserPreferences.current
        return prefs.pinnedSpotIDs.compactMap { id in
            Spot.samples.first(where: { $0.id == id })
        }
    }

    private func presentExpandedDetail() {
        guard let spot = detailPresenter.selectedSpot,
              presentedViewController == nil else { return }

        let host = UIHostingController(
            rootView: SpotDetailView(
                spot: spot,
                onClose: { [weak self] in self?.dismiss(animated: true) },
                summarizer: detailPresenter.summarizer
            )
        )
        host.preferredTransition = .zoom { [weak self] _ in
            self?.detailHost.view
        }
        present(host, animated: true)
    }
}
