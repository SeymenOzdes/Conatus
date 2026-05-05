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
    var coordinate: CLLocationCoordinate2D { spot.coordinate }
    var title: String? { spot.name }

    nonisolated init(spot: Spot) {
        self.spot = spot
    }
}

final class SpotMapView: MKMapView {

    private static let reuseID = "SpotMarker"

    // MARK: - Callbacks

    var onSpotSelected: ((Spot) -> Void)?
    var onSpotDeselected: (() -> Void)?

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

        setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 38.2887, longitude: 26.3778),
                span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
            ),
            animated: false
        )

        addAnnotations(Spot.samples.map(SpotAnnotation.init(spot:)))
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
        guard let spot = (view.annotation as? SpotAnnotation)?.spot else { return }
        onSpotSelected?(spot)
    }

    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        guard view.annotation is SpotAnnotation else { return }
        onSpotDeselected?()
    }
}
