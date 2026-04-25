//
//  SpotViewController.swift
//  Conatus
//
//  Created by Seymen Özdeş on 22.04.2026.
//

import SwiftUI
import UIKit
import MapKit

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

    // MARK: - Map

    private lazy var mapView: SpotMapView = {
        let map = SpotMapView(frame: .zero)
        map.translatesAutoresizingMaskIntoConstraints = false
        return map
    }()

    // MARK: - Detail sheet

    private let detailPresenter: SpotDetailPresenter

    // MARK: - Init

    init(detailPresenter: SpotDetailPresenter) {
        self.detailPresenter = detailPresenter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func loadView() {
        view = SpotView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        installMap()
        installSearchBar()
    }

    // MARK: - Layout

    private func installMap() {
        mapView.onSpotSelected = { [weak self] spot in
            self?.detailPresenter.selectedSpot = spot
        }
        mapView.onSpotDeselected = { [weak self] in
            self?.detailPresenter.selectedSpot = nil
        }
        spotView.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: spotView.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: spotView.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: spotView.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: spotView.bottomAnchor),
        ])
    }

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

    // MARK: - Actions

    func deselectAllSpots() {
        guard isViewLoaded else { return }
        for annotation in mapView.selectedAnnotations {
            mapView.deselectAnnotation(annotation, animated: true)
        }
    }
}

