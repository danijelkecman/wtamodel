import SwiftUI

struct DailyForecastTabView: View {
    @Bindable var viewModel: WTAViewModel
    @State private var dailyThreatCountText = ""
    @State private var dailyHitsText = ""
    @State private var dailyPerThreatTexts: [String] = []
    @State private var showDailyThreatBreakdown = false
    @State private var expandedSavedObservationIDs: Set<UUID> = []

    var body: some View {
        WtaScrollScreen {
            SectionCard(title: "Per day", systemImage: "calendar") {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker(
                        "Observation day",
                        selection: $viewModel.selectedObservationDate,
                        displayedComponents: .date
                    )
                    .tint(AppTheme.accent)

                    TextField("Incoming drones / missiles per day", text: $dailyThreatCountText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)

                    TextField("Hits per day", text: $dailyHitsText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)

                    if usesCondensedThreatUI {
                        Button(showDailyThreatBreakdown ? "Hide per-threat breakdown" : "Show per-threat breakdown") {
                            showDailyThreatBreakdown.toggle()
                        }
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent)

                        if showDailyThreatBreakdown {
                            ForEach(Array(viewModel.threats.enumerated()), id: \.element.id) { index, threat in
                                TextField("Incoming at \(threat.name)", text: binding(forDailyThreatAt: index))
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    } else {
                        ForEach(Array(viewModel.threats.enumerated()), id: \.element.id) { index, threat in
                            TextField("Incoming at \(threat.name)", text: binding(forDailyThreatAt: index))
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Button("Calculate per day") {
                        viewModel.applyDailyAnalysis(
                            threatCount: parsedDailyThreatCount,
                            hits: Int(dailyHitsText) ?? viewModel.dailyHits,
                            perThreatIncoming: parsedDailyPerThreatIncoming
                        )
                    }
                    .buttonStyle(SecondaryWtaButtonStyle())

                    Button("Save day") {
                        viewModel.applyDailyAnalysis(
                            threatCount: parsedDailyThreatCount,
                            hits: Int(dailyHitsText) ?? viewModel.dailyHits,
                            perThreatIncoming: parsedDailyPerThreatIncoming
                        )
                        viewModel.saveCurrentDailyObservation()
                        syncDailyInputsFromViewModel()
                    }
                    .buttonStyle(PrimaryWtaButtonStyle())

                    if viewModel.dailyThreatCount > 0 {
                        Text("Current: \(viewModel.dailyThreatCount) incoming, \(viewModel.dailyHits) hits")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Save day persists counts plus the current WTA snapshot (interceptors, doctrine, Monte Carlo) to disk.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            SectionCard(title: "Saved days", systemImage: "archivebox.fill") {
                if viewModel.dailyObservations.isEmpty {
                    Text("Save a day to build history, forecasts, and a persistent defense record.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.dailyObservations) { observation in
                        savedObservationRow(observation: observation)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Remove", role: .destructive) {
                                    removeObservation(id: observation.id)
                                }
                            }
                    }
                }
            }

            SectionCard(title: "Threat forecast", systemImage: "chart.line.uptrend.xyaxis") {
                if viewModel.threatForecasts.isEmpty {
                    Text("Save at least one day to predict the next wave by threat.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.threatForecasts) { forecast in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(forecast.threatName)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(forecast.predictedIncomingCount, format: .number.precision(.fractionLength(1)))
                                    .foregroundStyle(AppTheme.accent)
                                    .monospacedDigit()
                            }

                            Text(
                                "From \(forecast.sampleCount) saved days — recent avg \(forecast.recentAverage, format: .number.precision(.fractionLength(1))), trend \(forecast.trendPerDay, format: .number.precision(.fractionLength(1))) / day."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .disabled(viewModel.isComputing)
        .onAppear {
            syncDailyInputsFromViewModel()
        }
        .onChange(of: viewModel.dailyThreatCount) { _, _ in
            syncDailyInputsFromViewModel()
        }
        .onChange(of: viewModel.dailyHits) { _, _ in
            syncDailyInputsFromViewModel()
        }
        .onChange(of: viewModel.dailyPerThreatIncoming) { _, _ in
            syncDailyInputsFromViewModel()
        }
        .onChange(of: viewModel.threats.count) { _, _ in
            syncDailyInputsFromViewModel()
            if !usesCondensedThreatUI {
                showDailyThreatBreakdown = false
            }
        }
    }

    @ViewBuilder
    private func savedObservationRow(observation: DailyObservation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(observation.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Remove", role: .destructive) {
                    removeObservation(id: observation.id)
                }
                .font(.caption)
            }

            Text("\(observation.totalIncoming) incoming · \(observation.totalHits) hits · \(observation.successfulDefenses) defenses")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(observation.perThreatIncomingSummary)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if let snapshot = observation.calculationSnapshot {
                DisclosureGroup(
                    "Saved WTA calculation",
                    isExpanded: Binding(
                        get: { expandedSavedObservationIDs.contains(observation.id) },
                        set: { isOn in
                            if isOn {
                                expandedSavedObservationIDs.insert(observation.id)
                            } else {
                                expandedSavedObservationIDs.remove(observation.id)
                            }
                        }
                    )
                ) {
                    SavedSnapshotResultsView(snapshot: snapshot, observation: observation)
                        .padding(.top, 6)
                }
                .tint(AppTheme.accent)
            } else {
                Text("No snapshot (legacy save or no solver result).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var usesCondensedThreatUI: Bool {
        viewModel.threats.count > 12
    }

    private var parsedDailyPerThreatIncoming: [Int] {
        let trimmed = Array(dailyPerThreatTexts.prefix(viewModel.threats.count))
        let parsed = trimmed.map { Int($0) ?? 0 }

        if parsed.count < viewModel.threats.count {
            return parsed + Array(repeating: 0, count: viewModel.threats.count - parsed.count)
        }

        return parsed
    }

    private var parsedDailyThreatCount: Int {
        let perThreatTotal = parsedDailyPerThreatIncoming.reduce(0, +)
        return max(Int(dailyThreatCountText) ?? viewModel.dailyThreatCount, perThreatTotal)
    }

    private func binding(forDailyThreatAt index: Int) -> Binding<String> {
        Binding(
            get: {
                guard dailyPerThreatTexts.indices.contains(index) else { return "" }
                return dailyPerThreatTexts[index]
            },
            set: { newValue in
                if index >= dailyPerThreatTexts.count {
                    dailyPerThreatTexts.append(contentsOf: Array(repeating: "", count: index - dailyPerThreatTexts.count + 1))
                }
                dailyPerThreatTexts[index] = newValue
            }
        )
    }

    private func syncDailyInputsFromViewModel() {
        dailyThreatCountText = viewModel.dailyThreatCount > 0 ? "\(viewModel.dailyThreatCount)" : ""
        dailyHitsText = viewModel.dailyHits > 0 ? "\(viewModel.dailyHits)" : ""
        dailyPerThreatTexts = viewModel.dailyPerThreatIncoming.map { $0 > 0 ? "\($0)" : "" }
    }

    private func removeObservation(id: UUID) {
        guard let index = viewModel.dailyObservations.firstIndex(where: { $0.id == id }) else { return }
        viewModel.removeDailyObservations(at: IndexSet(integer: index))
    }
}
