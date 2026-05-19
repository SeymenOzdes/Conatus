//
//  ConditionTagStack.swift
//  Conatus
//

import SwiftUI

struct ConditionTagStack: View {
    let tags: [ConditionTag]

    private let chipSize: CGFloat = 22
    private let visibleLimit: Int = 3

    var body: some View {
        if tags.isEmpty {
            EmptyView()
        } else {
            let visible = Array(tags.prefix(visibleLimit).enumerated())
            let overflow = max(0, tags.count - visibleLimit)
            HStack(spacing: -7) {
                ForEach(visible, id: \.offset) { index, tag in
                    chip(code: tag.code, fill: tag.tint)
                        .zIndex(Double(visible.count - index))
                }
                if overflow > 0 {
                    chip(code: "+\(overflow)", fill: Color(white: 0.75))
                        .zIndex(0)
                }
            }
        }
    }

    private func chip(code: String, fill: Color) -> some View {
        Circle()
            .fill(fill)
            .overlay(Circle().stroke(.white, lineWidth: 1))
            .overlay(
                Text(code)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            )
            .frame(width: chipSize, height: chipSize)
    }
}
