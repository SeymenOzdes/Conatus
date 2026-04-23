//
//  SpotMapView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 23.04.2026.
//

import UIKit
import MapKit
import CoreLocation

final class SpotAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let symbol: String
    let tint: UIColor

    init(coordinate: CLLocationCoordinate2D, title: String, symbol: String, tint: UIColor) {
        self.coordinate = coordinate
        self.title = title
        self.symbol = symbol
        self.tint = tint
    }
}

final class SpotMapView: MKMapView {

    private static let reuseID = "SpotMarker"

    private let locationManager = CLLocationManager()

    private lazy var trackingButton: MKUserTrackingButton = {
        let button = MKUserTrackingButton(mapView: self)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)
        button.layer.cornerRadius = 10
        button.clipsToBounds = true
        return button
    }()

    private lazy var compassButton: MKCompassButton = {
        let button = MKCompassButton(mapView: self)
        button.compassVisibility = .adaptive
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

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

        showsUserLocation = true
        showsCompass = false
        showsScale = false
        isPitchEnabled = true
        isRotateEnabled = true

        delegate = self
        register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: Self.reuseID)

        setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 41.0186, longitude: 28.9784),
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
            ),
            animated: false
        )

        addAnnotations(Self.defaultSpots)
        installOverlays()
        locationManager.requestWhenInUseAuthorization()
    }

    private func installOverlays() {
        addSubview(compassButton)
        addSubview(trackingButton)

        NSLayoutConstraint.activate([
            compassButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            compassButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 80),

            trackingButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            trackingButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            trackingButton.widthAnchor.constraint(equalToConstant: 44),
            trackingButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    // MARK: - Sample data

    private static let defaultSpots: [SpotAnnotation] = [
        .init(coordinate: .init(latitude: 41.0086, longitude: 28.9802), title: "Hagia Sophia",      symbol: "building.columns.fill", tint: .systemOrange),
        .init(coordinate: .init(latitude: 41.0256, longitude: 28.9742), title: "Galata Tower",      symbol: "building.2.fill",       tint: .systemIndigo),
        .init(coordinate: .init(latitude: 41.0458, longitude: 29.0339), title: "Bosphorus Bridge",  symbol: "road.lanes",            tint: .systemTeal),
        .init(coordinate: .init(latitude: 41.0106, longitude: 28.9681), title: "Grand Bazaar",      symbol: "bag.fill",              tint: .systemBrown),
        .init(coordinate: .init(latitude: 41.0391, longitude: 29.0001), title: "Dolmabahçe Palace", symbol: "crown.fill",            tint: .systemPink),
    ]
}

// MARK: - MKMapViewDelegate

extension SpotMapView: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let spot = annotation as? SpotAnnotation else { return nil }
        let view = mapView.dequeueReusableAnnotationView(
            withIdentifier: Self.reuseID,
            for: annotation
        ) as! MKMarkerAnnotationView
        view.markerTintColor = spot.tint
        view.glyphImage = UIImage(systemName: spot.symbol)
        view.canShowCallout = true
        view.animatesWhenAdded = true
        return view
    }
}
