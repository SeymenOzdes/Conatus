//
//  SpotMapView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 23.04.2026.
//

import UIKit
import SwiftUI
import MapKit

final class SpotAnnotation: NSObject, MKAnnotation {
    let spot: Spot
    let searchResult: SpotResult?
    let key: String
    var coordinate: CLLocationCoordinate2D { spot.coordinate }
    var title: String? { spot.name }

    nonisolated init(spot: Spot, searchResult: SpotResult? = nil) {
        self.spot = spot
        self.searchResult = searchResult
        self.key = searchResult.map(Self.key(for:)) ?? Self.key(for: spot)
    }

    nonisolated static func key(for result: SpotResult) -> String {
        "search:\(result.spotId)"
    }

    nonisolated static func key(for spot: Spot) -> String {
        "spot:\(spot.id.uuidString)"
    }

    func isEquivalent(to other: SpotAnnotation) -> Bool {
        spot.name == other.spot.name
            && spot.symbol == other.spot.symbol
            && Self.coordinatesAreClose(spot.coordinate, other.spot.coordinate)
            && searchResult?.spotId == other.searchResult?.spotId
            && UIColor(spot.tint).isEqual(UIColor(other.spot.tint))
    }

    private static func coordinatesAreClose(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.0001
            && abs(lhs.longitude - rhs.longitude) < 0.0001
    }
}

final class SpotMapView: MKMapView {

    private static let reuseID = "SpotMarker"
    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.2887, longitude: 26.3778),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )
    private static let focusSpan = MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)

    // MARK: - Callbacks

    var onSpotSelected: ((Spot) -> Void)?
    var onSearchResultSelected: ((SpotResult) -> Void)?
    var onSpotDeselected: (() -> Void)?
    var onRegionChanged: ((CLLocationCoordinate2D) -> Void)?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    // MARK: - Configuration

    private func configure() {
        let config = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .default)
        config.pointOfInterestFilter = .includingAll
        preferredConfiguration = config
        showsUserLocation = UserPreferences.current.permissions.location == .granted
        showsCompass = false
        showsScale = false
        isPitchEnabled = true
        isRotateEnabled = true

        delegate = self
        register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: Self.reuseID)

        setRegion(Self.defaultRegion, animated: false)
    }

    // MARK: - Spot rendering

    func renderDefaultSpots(animated: Bool) {
        setRegion(Self.defaultRegion, animated: animated)
        reconcileSpotAnnotations(with: Spot.samples.map { SpotAnnotation(spot: $0) })
    }

    func renderSavedSpots(_ spots: [Spot], animated: Bool) {
        let annotations = spots.map { SpotAnnotation(spot: $0) }
        reconcileSpotAnnotations(with: annotations)
        focus(on: annotations, animated: animated)
    }

    func renderSearchResults(_ results: [SpotResult], animated: Bool) {
        let annotations = results.map { result in
            SpotAnnotation(spot: Spot.placeholder(from: result), searchResult: result)
        }
        reconcileSpotAnnotations(with: annotations)
        focus(on: annotations, animated: animated)
    }

    func center(on coordinate: CLLocationCoordinate2D, animated: Bool) {
        setRegion(
            MKCoordinateRegion(center: coordinate, span: Self.focusSpan),
            animated: animated
        )
    }

    private func reconcileSpotAnnotations(with annotations: [SpotAnnotation]) {
        let currentAnnotations = self.annotations.compactMap { $0 as? SpotAnnotation }

        var currentByKey: [String: SpotAnnotation] = [:]
        var duplicateCurrentAnnotations: [SpotAnnotation] = []
        for annotation in currentAnnotations {
            if currentByKey[annotation.key] == nil {
                currentByKey[annotation.key] = annotation
            } else {
                duplicateCurrentAnnotations.append(annotation)
            }
        }

        var desiredByKey: [String: SpotAnnotation] = [:]
        var desiredKeys: [String] = []
        for annotation in annotations where desiredByKey[annotation.key] == nil {
            desiredByKey[annotation.key] = annotation
            desiredKeys.append(annotation.key)
        }

        var annotationsToRemove = duplicateCurrentAnnotations
        for annotation in currentAnnotations {
            guard let desiredAnnotation = desiredByKey[annotation.key] else {
                annotationsToRemove.append(annotation)
                continue
            }

            if !annotation.isEquivalent(to: desiredAnnotation) {
                annotationsToRemove.append(annotation)
            }
        }

        let removedAnnotationIDs = Set(annotationsToRemove.map(ObjectIdentifier.init))
        let retainedKeys = Set(
            currentAnnotations
                .filter { !removedAnnotationIDs.contains(ObjectIdentifier($0)) }
                .map(\.key)
        )
        let annotationsToAdd = desiredKeys.compactMap { key -> SpotAnnotation? in
            guard let desiredAnnotation = desiredByKey[key] else { return nil }
            if retainedKeys.contains(key) {
                return nil
            }
            return desiredAnnotation
        }

        if !annotationsToRemove.isEmpty {
            removeAnnotations(annotationsToRemove)
        }
        if !annotationsToAdd.isEmpty {
            addAnnotations(annotationsToAdd)
        }
    }

    private func focus(on annotations: [SpotAnnotation], animated: Bool) {
        guard !annotations.isEmpty else { return }

        if annotations.count == 1, let coordinate = annotations.first?.coordinate {
            center(on: coordinate, animated: animated)
            return
        }

        let rect = annotations
            .map { MKMapPoint($0.coordinate) }
            .reduce(MKMapRect.null) { rect, point in
                rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
            }

        setVisibleMapRect(
            rect,
            edgePadding: UIEdgeInsets(top: 120, left: 48, bottom: 160, right: 48),
            animated: animated
        )
    }
}

// MARK: - MKMapViewDelegate

extension SpotMapView: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let spot = (annotation as? SpotAnnotation)?.spot else { return nil }
        let view = mapView.dequeueReusableAnnotationView(
            withIdentifier: Self.reuseID,
            for: annotation
        ) as! MKMarkerAnnotationView
        view.markerTintColor = UIColor(spot.tint)
        view.glyphImage = UIImage(systemName: spot.symbol)
        view.canShowCallout = false
        view.animatesWhenAdded = true
        return view
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation as? SpotAnnotation else { return }
        if let result = annotation.searchResult {
            onSearchResultSelected?(result)
        } else {
            onSpotSelected?(annotation.spot)
        }
    }

    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        guard view.annotation is SpotAnnotation else { return }
        onSpotDeselected?()
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        onRegionChanged?(mapView.centerCoordinate)
    }
}
