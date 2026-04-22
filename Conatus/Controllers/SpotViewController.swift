//
//  SpotViewController.swift
//  Conatus
//
//  Created by Seymen Özdeş on 22.04.2026.
//

import SwiftUI
import UIKit

final class SpotViewController: UIViewController {

    // MARK: - View

    private var spotView: SpotView { view as! SpotView }

    // MARK: - Search

    private struct SearchBarContainer: View {
        @State private var query = ""
        var body: some View {
            SearchBarView(text: $query, placeholder: "Search Spots")
        }
    }

    private lazy var searchBarHost: UIHostingController<SearchBarContainer> = {
        let host = UIHostingController(rootView: SearchBarContainer())
        host.view.backgroundColor = .clear
        return host
    }()

    // MARK: - Lifecycle

    override func loadView() {
        view = SpotView()
        view.backgroundColor = .systemBackground
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        installSearchBar()
    }

    // MARK: - Layout

    private func installSearchBar() {
        addChild(searchBarHost)
        let bar = searchBarHost.view!
        bar.translatesAutoresizingMaskIntoConstraints = false
        spotView.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: spotView.safeAreaLayoutGuide.topAnchor, constant: 12),
            bar.leadingAnchor.constraint(equalTo: spotView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            bar.trailingAnchor.constraint(equalTo: spotView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])
        searchBarHost.didMove(toParent: self)
    }
}
