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

    private let searchVM = SpotSearchViewModel()

    private struct SearchOverlayView: View {
        @Bindable var vm: SpotSearchViewModel
        var onSelectResult: (SpotResult) -> Void

        var body: some View {
            VStack(spacing: 8) {
                SearchBarView(text: $vm.query, placeholder: "Search Spots")
                SearchSuggestionsView(phase: vm.phase, query: vm.query) { id in
                    guard let result = vm.result(forID: id) else { return }
                    onSelectResult(result)
                }
                .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
            }
            .animation(.spring(duration: 0.38, bounce: 0.2), value: vm.phase)
            .onChange(of: vm.query) { _, _ in
                vm.onQueryChanged()
            }
        }
    }

    private lazy var searchOverlayHost: UIHostingController<SearchOverlayView> = {
        let host = UIHostingController(
            rootView: SearchOverlayView(vm: searchVM) { [weak self] result in
                self?.selectFromSearchResult(result)
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

    // MARK: - Add Spot

    private let addSpotPresenter: AddSpotPresenter

    private lazy var addButtonHost: UIHostingController<AddSpotButton> = {
        let host = UIHostingController(
            rootView: AddSpotButton { [weak self] in
                self?.addSpotPresenter.present()
            }
        )
        host.view.backgroundColor = .clear
        host.sizingOptions = .intrinsicContentSize
        return host
    }()

    /// Vertical offset of the add button's bottom edge from the spot view's bottom safe area.
    /// Matches the tab bar geometry owned by RootViewController:
    /// tab bar height (55) + bottom inset from safe area (8) + 12pt visual gap.
    private static let addButtonBottomOffset: CGFloat = -(55 + 8 + 12)

    private lazy var centerDotHost: UIHostingController<MapCenterDotView> = {
        let host = UIHostingController(rootView: MapCenterDotView(presenter: addSpotPresenter))
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        host.sizingOptions = .intrinsicContentSize
        return host
    }()

    /// Vertical distance from the top safe area to the dot's center while the
    /// Add Spot sheet covers the lower portion of the map. Approximates the
    /// midpoint of the visible map region above the sheet.
    private static let centerDotTopOffset: CGFloat = 180

    // MARK: - Init

    init(detailPresenter: SpotDetailPresenter, addSpotPresenter: AddSpotPresenter) {
        self.detailPresenter = detailPresenter
        self.addSpotPresenter = addSpotPresenter
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
        installAddButton()
        installCenterDot()
        installUserSpotsOnMap()
        observeUserSpots()
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

    private func installAddButton() {
        addChild(addButtonHost)
        let button = addButtonHost.view!
        button.translatesAutoresizingMaskIntoConstraints = false
        spotView.addSubview(button)
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: spotView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            button.bottomAnchor.constraint(equalTo: spotView.safeAreaLayoutGuide.bottomAnchor, constant: Self.addButtonBottomOffset),
        ])
        addButtonHost.didMove(toParent: self)
    }

    private func installCenterDot() {
        addChild(centerDotHost)
        let dot = centerDotHost.view!
        dot.translatesAutoresizingMaskIntoConstraints = false
        // Insert below the add button and search overlay so it can never block them,
        // but above the map so it stays visible while panning.
        spotView.insertSubview(dot, belowSubview: addButtonHost.view)
        NSLayoutConstraint.activate([
            dot.centerXAnchor.constraint(equalTo: spotView.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: spotView.safeAreaLayoutGuide.topAnchor, constant: Self.centerDotTopOffset),
        ])
        centerDotHost.didMove(toParent: self)
    }

    // MARK: - User spots

    private func installUserSpotsOnMap() {
        let spots = UserSpotsRepository.shared.spots.map(Spot.placeholder(from:))
        let annotations = spots.map(SpotAnnotation.init(spot:))
        mapView.addAnnotations(annotations)
    }

    private func observeUserSpots() {
        UserSpotsRepository.shared.onChange = { [weak self] spots in
            self?.syncUserSpotAnnotations(spots)
        }
    }

    private func syncUserSpotAnnotations(_ userSpots: [UserSpot]) {
        let knownIDs = Set(
            mapView.annotations
                .compactMap { ($0 as? SpotAnnotation)?.spot.id }
        )
        let newSpots = userSpots
            .filter { !knownIDs.contains($0.id) }
            .map(Spot.placeholder(from:))
        guard !newSpots.isEmpty else { return }
        mapView.addAnnotations(newSpots.map(SpotAnnotation.init(spot:)))

        // Pan to the newest spot so the user sees the result of the action.
        if let last = newSpots.last {
            mapView.setCenter(last.coordinate, animated: true)
        }
    }

    // MARK: - Actions

    private func selectFromSearchResult(_ result: SpotResult) {
        searchVM.query = result.name
        view.endEditing(true)

        let coordinate = CLLocationCoordinate2D(latitude: result.lat, longitude: result.lng)
        mapView.setCenter(coordinate, animated: true)

        if let annotation = mapView.annotations
            .compactMap({ $0 as? SpotAnnotation })
            .first(where: { $0.spot.name == result.name }) {
            mapView.selectAnnotation(annotation, animated: true)
        } else {
            detailPresenter.select(result)
        }
    }

    func deselectAllSpots() {
        guard isViewLoaded else { return }
        for annotation in mapView.selectedAnnotations {
            mapView.deselectAnnotation(annotation, animated: true)
        }
    }
}
