//
//  SearchBarView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 22.04.2026.
//

import SwiftUI

public struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String

    public init(text: Binding<String>, placeholder: String = "Search") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 15, weight: .medium))

            TextField(placeholder, text: $text)
                .font(.system(size: 17))
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassEffect(.regular, in: .capsule)
        .animation(.spring(duration: 0.2), value: text.isEmpty)
    }
}

#Preview {
    @Previewable @State var query = ""
    ZStack {
        Color.cyan.opacity(0.4).ignoresSafeArea()
        VStack(spacing: 20) {
            SearchBarView(text: $query, placeholder: "Search Plane Finder")
                .padding(.horizontal, 16)
            SearchBarView(text: .constant("UAAL 142"), placeholder: "Search")
                .padding(.horizontal, 16)
        }
    }
}
