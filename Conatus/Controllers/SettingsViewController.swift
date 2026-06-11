//
//  SettingsViewController.swift
//  Conatus
//
//  Created by Codex on 11.06.2026.
//

import SwiftUI
import UIKit

final class SettingsViewController: UIViewController {

    // MARK: - Content

    private let viewModel = SettingsViewModel()

    private lazy var contentHost: UIHostingController<SettingsContentView> = {
        let host = UIHostingController(
            rootView: SettingsContentView(viewModel: viewModel)
        )
        host.view.backgroundColor = .clear
        return host
    }()

    // MARK: - Lifecycle

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemGroupedBackground
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        installContent()
    }

    func refreshForDisplay() {
        viewModel.refreshFromStorage()
        Task {
            await viewModel.refreshSubscriptionStatus()
        }
    }

    func commitPendingChanges() {
        viewModel.commitNameDraft()
    }

    // MARK: - Layout

    private func installContent() {
        addChild(contentHost)
        let content = contentHost.view!
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        contentHost.didMove(toParent: self)
    }
}
