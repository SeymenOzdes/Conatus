//
//  HomeGlassActionBar.swift
//  Conatus
//
//  Created by Seymen Özdeş on 15.04.2026.
//

import SwiftUI
import UIKit

/// SwiftUI Liquid Glass action bar hosting the calendar and overflow buttons.
/// Both buttons share a single `GlassEffectContainer` so adjacent presses morph/merge.
struct HomeGlassActionBar: View {
    var onCalendar: () -> Void
    var onMore: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onCalendar) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                .tint(.white)
                .accessibilityLabel("Calendar")

                Button(action: onMore) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .tint(.white)
                .accessibilityLabel("More")
            }
        }
        .fixedSize()
    }
}

/// Builds the `UIHostingController` wrapping `HomeGlassActionBar` with the
/// configuration HomeView needs (clear background, intrinsic sizing, no safe-area inflation).
enum HomeGlassActionBarFactory {
    @MainActor
    static func make(
        onCalendar: @escaping () -> Void,
        onMore: @escaping () -> Void
    ) -> UIHostingController<HomeGlassActionBar> {
        let host = UIHostingController(
            rootView: HomeGlassActionBar(onCalendar: onCalendar, onMore: onMore)
        )
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.sizingOptions = [.intrinsicContentSize]
        host.safeAreaRegions = []
        return host
    }
}
