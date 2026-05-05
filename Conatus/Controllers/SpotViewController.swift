//
//  SpotViewController.swift
//  Conatus
//
//  Created by Seymen Özdeş on 22.04.2026.
//

import SwiftUI
import UIKit
import MapKit

@Observable
final class SpotSearchState {
    var query: String = ""
}

final class SpotViewController: UIViewController {

    // MARK: - View

    private var spotView: SpotView { view as! SpotView }

    // MARK: - Search

    private let searchState = SpotSearchState()

    private struct SearchOverlayView: View {
        @Bindable var state: SpotSearchState
        let spots: [Spot]
        var onSelect: (Spot) -> Void

        private var filtered: [Spot] {
            guard !state.query.isEmpty else { return [] }
            return Array(
                spots
                    .filter { $0.name.localizedCaseInsensitiveContains(state.query) }
                    .prefix(5)
            )
        }

        var body: some View {
            VStack(spacing: 8) {
                SearchBarView(text: $state.query, placeholder: "Search Spots")
                if !filtered.isEmpty {
                    SearchSuggestionsView(spots: filtered, onSelect: onSelect)
                        .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.38, bounce: 0.2), value: filtered.map(\.id))
        }
    }

    private lazy var searchOverlayHost: UIHostingController<SearchOverlayView> = {
        let host = UIHostingController(
            rootView: SearchOverlayView(state: searchState, spots: Spot.samples) { [weak self] spot in
                self?.selectFromSearch(spot)
            }
        )
        host.view.backgroundColor = .clear
        host.sizingOptions = .intrinsicContentSize
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
            self?.detailPresenter.select(spot)
        }
        mapView.onSpotDeselected = { [weak self] in
            self?.detailPresenter.select(nil)
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
        addChild(searchOverlayHost)
        let overlay = searchOverlayHost.view!
        overlay.translatesAutoresizingMaskIntoConstraints = false
        spotView.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: spotView.safeAreaLayoutGuide.topAnchor, constant: 12),
            overlay.leadingAnchor.constraint(equalTo: spotView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            overlay.trailingAnchor.constraint(equalTo: spotView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])
        searchOverlayHost.didMove(toParent: self)
    }

    // MARK: - Actions

    // `Spot.samples` regenerates UUIDs on every access, so match by name (unique across samples).
    private func selectFromSearch(_ spot: Spot) {
        let target = mapView.annotations
            .compactMap { $0 as? SpotAnnotation }
            .first { $0.spot.name == spot.name }
        guard let annotation = target else { return }
        searchState.query = spot.name
        view.endEditing(true)
        mapView.setCenter(annotation.coordinate, animated: true)
        mapView.selectAnnotation(annotation, animated: true)
    }

    func deselectAllSpots() {
        guard isViewLoaded else { return }
        for annotation in mapView.selectedAnnotations {
            mapView.deselectAnnotation(annotation, animated: true)
        }
    }
}
