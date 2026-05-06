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

    override func loadView() {
        view = HomeView()
        view.backgroundColor = .systemBackground
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

#if DEBUG
        installDebugResetGesture()
#endif
    }

#if DEBUG

    // MARK: - Debug

    private func installDebugResetGesture() {
        let recognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleDebugLongPress(_:))
        )
        recognizer.minimumPressDuration = 1.5
        recognizer.numberOfTouchesRequired = 2
        view.addGestureRecognizer(recognizer)
    }

    @objc private func handleDebugLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        UserDefaults.standard.removeObject(forKey: UserPreferences.onboardingFlagKey)
        let alert = UIAlertController(
            title: "Onboarding reset",
            message: "Relaunch the app to replay onboarding.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
#endif
}
