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
    }

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        installActionBar()
    }

    // MARK: - Setup

    private func installActionBar() {
        let host = HomeGlassActionBarFactory.make(
            onCalendar: { [weak self] in self?.handleCalendarTap() },
            onMore:     { [weak self] in self?.handleMoreTap() }
        )
        addChild(host)
        homeView.install(actionBar: host.view)
        host.didMove(toParent: self)
    }

    // MARK: - Actions

    private func handleCalendarTap() {
        // Hook for future calendar presentation.
    }

    private func handleMoreTap() {
        // Hook for future overflow menu.
    }
}
