//
//  SpotViewController.swift
//  Conatus
//
//  Created by Seymen Özdeş on 22.04.2026.
//

import SwiftUI
import UIKit
import MapKit

@MainActor
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
    private let startupSearchService = SearchService()
    private let currentLocationRequester = CurrentLocationRequester()
    private var startupMapTask: Task<Void, Never>?

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

    deinit {
        startupMapTask?.cancel()
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
        observeUserSpots()
        loadStartupMapContent()
    }

    // MARK: - Layout

    private func installMap() {
        mapView.onSpotSelected = { [weak self] spot in
            self?.detailPresenter.select(spot)
        }
        mapView.onSearchResultSelected = { [weak self] result in
            self?.detailPresenter.select(result)
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

    private func observeUserSpots() {
        UserSpotsRepository.shared.onChange = { [weak self] spots in
            self?.handleUserSpotsChanged(spots)
        }
    }

    private func handleUserSpotsChanged(_ userSpots: [UserSpot]) {
        startupMapTask?.cancel()
        if !renderPreferredStartupContent(animated: true) {
            loadStartupMapContent()
        }
    }

    // MARK: - Startup map content

    private func loadStartupMapContent() {
        startupMapTask?.cancel()

        if renderPreferredStartupContent(animated: false) {
            return
        }

        guard currentLocationRequester.isAuthorized else {
            mapView.renderDefaultSpots(animated: false)
            return
        }

        startupMapTask = Task { [weak self] in
            guard let self else { return }
            guard let coordinate = await currentLocationRequester.requestCurrentCoordinate() else {
                renderDefaultSpotsIfStillNeeded(animated: false)
                return
            }

            guard !Task.isCancelled, !hasPreferredStartupContent else { return }
            mapView.center(on: coordinate, animated: false)

            do {
                let response = try await startupSearchService.searchNearby(
                    lat: coordinate.latitude,
                    lng: coordinate.longitude,
                    limit: 20
                )
                guard !Task.isCancelled, !hasPreferredStartupContent else { return }
                if response.spots.isEmpty {
                    mapView.renderDefaultSpots(animated: true)
                } else {
                    mapView.renderSearchResults(response.spots, animated: true)
                }
            } catch {
                guard !Task.isCancelled else { return }
                renderDefaultSpotsIfStillNeeded(animated: true)
            }
        }
    }

    @discardableResult
    private func renderPreferredStartupContent(animated: Bool) -> Bool {
        let pinnedSpots = FavoriteSpotsResolver.pinnedSpots()
        if !pinnedSpots.isEmpty {
            mapView.renderSavedSpots(pinnedSpots, animated: animated)
            return true
        }

        return renderLocalUserSpotsIfAvailable(UserSpotsRepository.shared.spots, animated: animated)
    }

    private var hasPreferredStartupContent: Bool {
        !FavoriteSpotsResolver.pinnedSpots().isEmpty || !UserSpotsRepository.shared.spots.isEmpty
    }

    @discardableResult
    private func renderLocalUserSpotsIfAvailable(_ userSpots: [UserSpot], animated: Bool) -> Bool {
        guard !userSpots.isEmpty else { return false }
        mapView.renderSavedSpots(userSpots.map(Spot.placeholder(from:)), animated: animated)
        return true
    }

    private func renderDefaultSpotsIfStillNeeded(animated: Bool) {
        guard !renderPreferredStartupContent(animated: animated) else {
            return
        }
        mapView.renderDefaultSpots(animated: animated)
    }

    // MARK: - Actions

    private func selectFromSearchResult(_ result: SpotResult) {
        startupMapTask?.cancel()
        startupMapTask = nil
        searchVM.finishSelection(with: result.name)
        view.endEditing(true)

        let annotation = annotation(for: result) ?? addSearchResultAnnotation(result)
        let wasSelected = mapView.selectedAnnotations.contains {
            ($0 as? SpotAnnotation) === annotation
        }
        mapView.center(on: result.coordinate, animated: true)
        mapView.selectAnnotation(annotation, animated: true)
        if wasSelected {
            detailPresenter.select(result)
        }
    }

    private func annotation(for result: SpotResult) -> SpotAnnotation? {
        mapView.annotations
            .compactMap { $0 as? SpotAnnotation }
            .first { annotation in
                if annotation.searchResult?.spotId == result.spotId {
                    return true
                }
                return annotation.spot.name == result.name
                    && annotation.spot.coordinate.isClose(to: result.coordinate)
            }
    }

    private func addSearchResultAnnotation(_ result: SpotResult) -> SpotAnnotation {
        let annotation = SpotAnnotation(
            spot: Spot.placeholder(from: result),
            searchResult: result
        )
        mapView.addAnnotation(annotation)
        return annotation
    }

    func deselectAllSpots() {
        guard isViewLoaded else { return }
        for annotation in mapView.selectedAnnotations {
            mapView.deselectAnnotation(annotation, animated: true)
        }
    }
}

@MainActor
private final class CurrentLocationRequester: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    private var timeoutTask: Task<Void, Never>?

    var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    deinit {
        timeoutTask?.cancel()
        continuation?.resume(returning: nil)
    }

    func requestCurrentCoordinate() async -> CLLocationCoordinate2D? {
        guard isAuthorized else { return nil }

        if let cachedLocation = manager.location,
           abs(cachedLocation.timestamp.timeIntervalSinceNow) < 300 {
            return cachedLocation.coordinate
        }

        return await withCheckedContinuation { continuation in
            self.continuation?.resume(returning: nil)
            self.continuation = continuation
            manager.requestLocation()
            timeoutTask?.cancel()
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { return }
                self?.finishRequest(with: nil)
            }
        }
    }

    private func finishRequest(with coordinate: CLLocationCoordinate2D?) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(returning: coordinate)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor [weak self] in
            self?.finishRequest(with: coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.finishRequest(with: nil)
        }
    }
}

private extension SpotResult {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

private extension CLLocationCoordinate2D {
    func isClose(to other: CLLocationCoordinate2D) -> Bool {
        abs(latitude - other.latitude) < 0.0001
            && abs(longitude - other.longitude) < 0.0001
    }
}
