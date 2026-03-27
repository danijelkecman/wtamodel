import SwiftUI

/// Renders WTA outputs stored when a daily entry was saved (threat rows are display stubs).
struct SavedSnapshotResultsView: View {
    let snapshot: DailyCalculationSnapshot
    let observation: DailyObservation

    private var stubThreats: [Threat] {
        snapshot.savedThreats.map { Threat.displayStub(id: $0.id, name: $0.name) }
    }

    private var interceptorBudgetLabel: String {
        if let n = snapshot.totalInterceptors {
            return "\(n) shared interceptors"
        }
        return "no global interceptor cap"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Defense at save: \(interceptorBudgetLabel), \(snapshot.greedyResult.doctrine.displayName), \(snapshot.monteCarloSamples) MC samples")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let exact = snapshot.exactResult {
                ResultSectionView(
                    result: exact,
                    threats: stubThreats,
                    dailyEstimate: snapshot.exactDailyEstimate,
                    dailyThreatCount: observation.totalIncoming,
                    dailyHits: observation.totalHits
                )
            } else if let exactDaily = snapshot.exactDailyEstimate {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Exact solver")
                        .font(.subheadline.weight(.semibold))
                    Text("Optimal allocation was not computed at save (search space too large). Daily estimate using the exact method is shown below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    savedDailyEstimateBlock(estimate: exactDaily, label: "Per day (exact method)")
                }
            }

            if let mc = snapshot.greedyResult.monteCarlo, snapshot.monteCarloSamples > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monte Carlo (greedy allocation)")
                        .font(.subheadline.weight(.semibold))
                    MonteCarloResultBlock(summary: mc)
                }
            }

            ResultSectionView(
                result: snapshot.greedyResult,
                threats: stubThreats,
                dailyEstimate: snapshot.greedyDailyEstimate,
                dailyThreatCount: observation.totalIncoming,
                dailyHits: observation.totalHits,
                showMonteCarlo: false
            )
        }
    }

    private func savedDailyEstimateBlock(estimate: DailyDefenseEstimate, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline.weight(.semibold))

            Text("Modeled defense rate: \(estimate.successRate, format: .percent.precision(.fractionLength(1)))")
            Text(
                "Expected successful intercepts: \(estimate.expectedSuccessfulIntercepts, format: .number.precision(.fractionLength(1))) of \(estimate.incomingCount)"
            )
            Text("Expected leak-through: \(estimate.expectedLeakThrough, format: .number.precision(.fractionLength(1)))")
            Text("Expected shots consumed: \(estimate.expectedShotsConsumed, format: .number.precision(.fractionLength(1)))")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
