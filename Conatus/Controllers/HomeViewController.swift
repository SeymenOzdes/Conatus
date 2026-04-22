//
//  HomeViewController.swift
//  Conatus
//
//  Created by Seymen Özdeş on 11.04.2026.
//

import UIKit

final class HomeViewController: UIViewController {

    // MARK: - View

    private var homeView: HomeView { view as! HomeView }

    override func loadView() {
        view = HomeView()
        view.backgroundColor = UIColor.systemGray6
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
