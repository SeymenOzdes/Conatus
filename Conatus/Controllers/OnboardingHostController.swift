//
//  OnboardingHostController.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import UIKit
import SwiftUI

final class OnboardingHostController: UIHostingController<OnboardingFlowView> {

    init(onComplete: @escaping () -> Void) {
        super.init(rootView: OnboardingFlowView(onComplete: onComplete))
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
