//
//  HomeToastController.swift
//  Conatus
//
//  Lightweight @Observable signal so a parent (RootViewController) can ask the
//  Home screen to flash a transient confirmation. Kept tiny on purpose — adding
//  a NotificationCenter dependency for one toast would be overkill.
//

import Foundation
import Observation

@MainActor
@Observable
final class HomeToastController {
    var visible: Bool = false
    var message: String = ""

    private var hideTask: Task<Void, Never>?

    func show(_ text: String, duration: TimeInterval = 1.8) {
        hideTask?.cancel()
        message = text
        visible = true
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, let self else { return }
            self.visible = false
        }
    }
}
