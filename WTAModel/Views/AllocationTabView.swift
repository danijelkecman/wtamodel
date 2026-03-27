import SwiftUI

struct AllocationTabView: View {
    @Bindable var viewModel: WTAViewModel
    @State private var quickThreatCountText = ""
    @State private var quickInterceptorCountText = ""
    @State private var expandedThreatIDs: Set<UUID> = []
    @FocusState private var interceptorCountFieldFocused: Bool

    var body: some View {
        WtaScrollScreen {
            SectionCard(title: "Scenario", systemImage: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Drone / missile count", text: $quickThreatCountText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)

                    TextField("Interceptor count (empty = limitless)", text: $quickInterceptorCountText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($interceptorCountFieldFocused)

                    Text("This value drives total interceptors in the solver. Tap outside the field or use Recalculate to apply edits. Empty means limitless interceptors.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Button("Recalculate options") {
                        commitInterceptorBudgetFromField()
                        viewModel.applyScenarioCounts(
                            incomingCount: Int(quickThreatCountText) ?? viewModel.dailyThreatCount,
                            totalInterceptors: viewModel.totalInterceptors
                        )
                        quickThreatCountText = ""
                        syncInterceptorFieldFromViewModel()
                    }
                    .buttonStyle(PrimaryWtaButtonStyle())
                }

                Picker("Doctrine", selection: Binding(
                    get: { viewModel.doctrine },
                    set: {
                        viewModel.doctrine = $0
                        viewModel.recompute()
                    }
                )) {
                    ForEach(EngagementDoctrine.allCases) { doctrine in
                        Text(doctrine.displayName).tag(doctrine)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)

                Text(viewModel.doctrine.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stepper(
                    value: Binding(
                        get: { viewModel.monteCarloSamples },
                        set: {
                            viewModel.monteCarloSamples = $0
                            viewModel.recompute()
                        }
                    ),
                    in: 0...2000,
                    step: 100
                ) {
                    HStack {
                        Text("Monte Carlo samples")
                        Spacer()
                        Text("\(viewModel.monteCarloSamples)")
                            .foregroundStyle(AppTheme.accent)
                            .monospacedDigit()
                    }
                }
            }

            SectionCard(title: "Threats", systemImage: "scope") {
                if usesCondensedThreatUI {
                    HStack(spacing: 12) {
                        Button("Expand all") {
                            expandedThreatIDs = Set(viewModel.threats.map(\.id))
                        }
                        .buttonStyle(SecondaryWtaButtonStyle())

                        Button("Collapse all") {
                            expandedThreatIDs.removeAll()
                        }
                        .buttonStyle(SecondaryWtaButtonStyle())
                    }
                    .font(.caption)
                }

                ForEach(viewModel.threats) { threat in
                    VStack(alignment: .leading, spacing: 0) {
                        if usesCondensedThreatUI {
                            condensedThreatRow(threatID: threat.id)
                        } else {
                            ThreatEditorView(
                                threat: binding(for: threat.id),
                                maxInterceptors: viewModel.totalInterceptors,
                                residualPerThreatCapBudget: residualCapBudget(for: threat.id),
                                onRemove: { removeThreat(id: threat.id) }
                            ) {
                                viewModel.recompute()
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Remove", role: .destructive) {
                            removeThreat(id: threat.id)
                        }
                    }
                }

                Button {
                    viewModel.addThreat()
                } label: {
                    Label("Add threat", systemImage: "plus.circle.fill")
                }
                .buttonStyle(SecondaryWtaButtonStyle())

                if let globalBudget = viewModel.totalInterceptors, viewModel.threats.contains(where: { $0.maxAssignedInterceptors != nil }) {
                    Text("Per-threat limits total \(viewModel.sumOfPerThreatInterceptorCaps) of \(globalBudget) interceptors.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Educational model only: no timing, geometry, decoys, correlation, or dynamic retargeting.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            SectionCard(title: "Marginal gain", systemImage: "chart.xyaxis.line") {
                MarginalGainChartView(
                    threats: viewModel.threats,
                    globalInterceptorBudget: viewModel.totalInterceptors
                )
            }

            if let exactResult = viewModel.exactResult {
                SectionCard(title: "Exact solver", systemImage: "checkmark.seal.fill") {
                    ResultSectionView(
                        result: exactResult,
                        threats: viewModel.threats,
                        dailyEstimate: viewModel.exactDailyEstimate,
                        dailyThreatCount: viewModel.dailyThreatCount,
                        dailyHits: viewModel.dailyHits
                    )
                }
            } else if let exactSolverNote = viewModel.exactSolverNote {
                SectionCard(title: "Exact solver", systemImage: "exclamationmark.triangle.fill") {
                    Text(exactSolverNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let greedyResult = viewModel.greedyResult {
                if let mc = greedyResult.monteCarlo, viewModel.monteCarloSamples > 0 {
                    SectionCard(title: "Monte Carlo (greedy allocation)", systemImage: "chart.bar.xaxis") {
                        MonteCarloResultBlock(summary: mc)
                    }
                }

                SectionCard(title: "Greedy heuristic", systemImage: "hare.fill") {
                    ResultSectionView(
                        result: greedyResult,
                        threats: viewModel.threats,
                        dailyEstimate: viewModel.greedyDailyEstimate,
                        dailyThreatCount: viewModel.dailyThreatCount,
                        dailyHits: viewModel.dailyHits,
                        showMonteCarlo: false
                    )
                }
            }
        }
        .disabled(viewModel.isComputing)
        .onAppear {
            syncInterceptorFieldFromViewModel()
        }
        .onChange(of: viewModel.totalInterceptors) { _, _ in
            if !interceptorCountFieldFocused {
                syncInterceptorFieldFromViewModel()
            }
        }
        .onChange(of: interceptorCountFieldFocused) { _, isFocused in
            if !isFocused {
                commitInterceptorBudgetFromField()
            }
        }
    }

    private func syncInterceptorFieldFromViewModel() {
        quickInterceptorCountText = viewModel.totalInterceptors.map(String.init) ?? ""
    }

    /// Parses Interceptor count and updates the model so allocation matches the field (not only after Recalculate).
    private func commitInterceptorBudgetFromField() {
        let trimmed = quickInterceptorCountText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            viewModel.applyInterceptorBudget(nil)
        } else if let value = Int(trimmed), value >= 0 {
            viewModel.applyInterceptorBudget(value)
        } else {
            syncInterceptorFieldFromViewModel()
            return
        }
        syncInterceptorFieldFromViewModel()
    }

    private func residualCapBudget(for threatID: UUID) -> Int {
        guard viewModel.totalInterceptors != nil else { return Int.max }
        return viewModel.residualBudgetForPerThreatCap(excludingThreatID: threatID)
    }

    private var usesCondensedThreatUI: Bool {
        viewModel.threats.count > 12
    }

    @ViewBuilder
    private func condensedThreatRow(threatID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                toggleThreatExpansion(threatID)
            } label: {
                HStack {
                    Text(threatName(for: threatID))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(expandedThreatIDs.contains(threatID) ? "Hide" : "Edit")
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .buttonStyle(.plain)

            if expandedThreatIDs.contains(threatID) {
                ThreatEditorView(
                    threat: binding(for: threatID),
                    maxInterceptors: viewModel.totalInterceptors,
                    residualPerThreatCapBudget: residualCapBudget(for: threatID),
                    onRemove: { removeThreat(id: threatID) }
                ) {
                    viewModel.recompute()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func threatName(for id: UUID) -> String {
        viewModel.threats.first(where: { $0.id == id })?.name ?? ""
    }

    private func binding(for threatID: UUID) -> Binding<Threat> {
        Binding(
            get: {
                viewModel.threats.first(where: { $0.id == threatID })
                    ?? Threat(id: threatID, name: "", value: 0, baseShotProbability: 0, followOnDecay: 0, pTrack: 0, uncertainty: 0)
            },
            set: { newValue in
                if let index = viewModel.threats.firstIndex(where: { $0.id == threatID }) {
                    viewModel.threats[index] = newValue
                }
            }
        )
    }

    private func toggleThreatExpansion(_ id: UUID) {
        if expandedThreatIDs.contains(id) {
            expandedThreatIDs.remove(id)
        } else {
            expandedThreatIDs.insert(id)
        }
    }

    private func removeThreat(id: UUID) {
        guard let index = viewModel.threats.firstIndex(where: { $0.id == id }) else { return }
        viewModel.removeThreat(at: IndexSet(integer: index))
        expandedThreatIDs.remove(id)
    }
}
