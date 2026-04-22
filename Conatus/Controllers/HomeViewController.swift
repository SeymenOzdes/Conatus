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
    
    private lazy var tabBarHost: UIHostingController<GlassTabBarView> = {
        
        let host = UIHostingController(rootView: GlassTabBarView())
        host.view.backgroundColor = .clear
        return host
    }()

    override func loadView() {
        view = HomeView()
        view.backgroundColor = UIColor.systemGray6
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
         installTabBar()
    }

    // MARK: - Layout
    
    private func installTabBar() {
        addChild(tabBarHost)
        let tabBar = tabBarHost.view!
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        homeView.addSubview(tabBar)
        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: homeView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            tabBar.trailingAnchor.constraint(equalTo: homeView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            tabBar.bottomAnchor.constraint(equalTo: homeView.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
        tabBarHost.didMove(toParent: self)
    }
     
}
