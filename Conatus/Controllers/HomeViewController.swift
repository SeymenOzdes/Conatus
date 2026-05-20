//
//  HomeViewController.swift
//  Conatus
//
//  Created by Seymen Özdeş on 11.04.2026.
//

import SwiftUI
import UIKit

final class HomeViewController: UIViewController {

    // MARK: - View

    private var homeView: HomeView { view as! HomeView }

    // MARK: - Content

    private let viewModel = HomeViewModel()
    private let startSessionPresenter: StartSessionPresenter
    private let toastController: HomeToastController

    init(startSessionPresenter: StartSessionPresenter, toastController: HomeToastController) {
        self.startSessionPresenter = startSessionPresenter
        self.toastController = toastController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var contentHost: UIHostingController<HomeContentView> = {
        let host = UIHostingController(
            rootView: HomeContentView(
                viewModel: viewModel,
                startSessionPresenter: startSessionPresenter,
                toastController: toastController
            )
        )
        host.view.backgroundColor = .clear
        return host
    }()

    override func loadView() {
        view = HomeView()
        view.backgroundColor = .systemBackground
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        installContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.refresh()
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
