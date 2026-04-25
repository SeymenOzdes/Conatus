//
//  GlassTabBarView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 22.04.2026.
//
import SwiftUI

struct GlassTabBarView: View {
    @State private var activeTab: CustomTab = .home
    var onTabSelected: ((CustomTab) -> Void)?

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                GeometryReader {
                    GlassTabBar(size: $0.size, activeTabs: $activeTab) { tab in
                        VStack(spacing: 3) {
                            Image(systemName: tab.symbol)
                                .font(.title3)

                            Text(tab.rawValue)
                                .font(.system(size: 10))
                                .fontWeight(.medium)
                        }
                        .symbolVariant(.fill)
                        .frame(maxWidth: .infinity)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
            .frame(height: 55)
        }
        .padding(.horizontal, 20)
        .onChange(of: activeTab) { _, newTab in
            onTabSelected?(newTab)
        }
    }
}

#Preview {
    GlassTabBarView()
}
