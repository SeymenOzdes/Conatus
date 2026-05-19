//
//  GreetingHeaderView.swift
//  Conatus
//

import SwiftUI

struct GreetingHeaderView: View {
    let name: String?

    private let accent = Color(red: 0.0, green: 0.74, blue: 0.74)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(greetingWord),")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
            Text(displayedName + ".")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }

    private var greetingWord: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<18: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var displayedName: String {
        name.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 } ?? "Friend"
    }
}
