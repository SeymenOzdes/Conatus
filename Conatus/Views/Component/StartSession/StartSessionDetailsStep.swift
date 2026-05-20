//
//  StartSessionDetailsStep.swift
//  Conatus
//

import SwiftUI

struct StartSessionDetailsStep: View {
    @Bindable var presenter: StartSessionPresenter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                waveCountSection
                durationSection
                SessionSelectionList(
                    label: "Board",
                    options: BoardType.allCases,
                    selection: $presenter.boardType,
                    title: { $0.displayName },
                    icon: { $0.iconName }
                )
                SessionSelectionList(
                    label: "Wave size",
                    options: WaveSize.allCases,
                    selection: $presenter.waveSize,
                    title: { $0.displayName },
                    icon: { $0.iconName }
                )
                SessionSelectionList(
                    label: "Crowd",
                    options: CrowdLevel.allCases,
                    selection: $presenter.crowdLevel,
                    title: { $0.displayName },
                    icon: { $0.iconName }
                )
                ratingSection
                notesSection
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 480)
        .scrollIndicators(.hidden)
    }

    // MARK: - Sections

    private var waveCountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Waves caught")
            fieldCard {
                HStack(spacing: 12) {
                    Button {
                        presenter.waveCount = max(0, presenter.waveCount - 1)
                    } label: {
                        stepperGlyph("minus")
                    }
                    .buttonStyle(.plain)

                    Text("\(presenter.waveCount)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .frame(minWidth: 56)
                        .contentTransition(.numericText())

                    Button {
                        presenter.waveCount += 1
                    } label: {
                        stepperGlyph("plus")
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Duration")
            fieldCard {
                HStack(spacing: 12) {
                    DatePicker("Start", selection: $presenter.startedAt, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .colorScheme(.dark)
                    Text("→")
                        .foregroundStyle(Color.white.opacity(0.65))
                    DatePicker("End", selection: $presenter.endedAt, in: presenter.startedAt..., displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .colorScheme(.dark)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Vibe")
            fieldCard {
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            presenter.rating = value
                        } label: {
                            Image(systemName: value <= presenter.rating ? "star.fill" : "star")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(value <= presenter.rating ? Color.white : Color.white.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(value) star\(value == 1 ? "" : "s")")
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Notes")
            TextField("How did it feel?", text: $presenter.notes, axis: .vertical)
                .lineLimit(3...5)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .tint(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                )
        }
    }

    // MARK: - Helpers

    private func fieldCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
            )
    }

    private func stepperGlyph(_ system: String) -> some View {
        Image(systemName: system)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Circle().fill(Color.white.opacity(0.18)))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.65))
            .tracking(0.6)
    }
}
