import SwiftUI

/// Monte Carlo uncertainty for a single allocation result (exact or greedy).
struct MonteCarloResultBlock: View {
  let summary: MonteCarloSummary
  
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Monte Carlo (\(summary.samples) samples)")
        .font(.subheadline.weight(.semibold))
      
      Text(
        "Mean defended value: \(summary.meanExpectedValue, format: .number.precision(.fractionLength(2)))"
      )
      Text(
        "10-90% band: \(summary.p10ExpectedValue, format: .number.precision(.fractionLength(2))) to \(summary.p90ExpectedValue, format: .number.precision(.fractionLength(2)))"
      )
      Text(
        "Mean shots consumed: \(summary.meanExpectedShots, format: .number.precision(.fractionLength(2)))"
      )
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }
}

struct ResultSectionView: View {
  let result: AllocationResult
  let threats: [Threat]
  let dailyEstimate: DailyDefenseEstimate?
  let dailyThreatCount: Int
  let dailyHits: Int
  /// When false, omit the Monte Carlo block (use a sibling section instead, e.g. for greedy).
  var showMonteCarlo: Bool = true
  @State private var showPerThreatDetails = false
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(result.method)
          .font(.headline)
        Spacer()
        Text(result.totalExpectedValue, format: .number.precision(.fractionLength(2)))
          .font(.headline)
      }
      
      Text("Expected defended value")
        .font(.caption)
        .foregroundStyle(.secondary)
      
      HStack {
        Text("Doctrine")
        Spacer()
        Text(result.doctrine.displayName)
          .foregroundStyle(.secondary)
      }
      
      HStack {
        Text("Expected shots consumed")
        Spacer()
        Text(result.totalExpectedShots, format: .number.precision(.fractionLength(2)))
          .foregroundStyle(.secondary)
      }
      
      if let dailyEstimate {
        VStack(alignment: .leading, spacing: 4) {
          Text("Per day estimate")
            .font(.subheadline.weight(.semibold))
          
          Text("Modeled defense rate: \(dailyEstimate.successRate, format: .percent.precision(.fractionLength(1)))")
          Text(
            "Expected successful intercepts: \(dailyEstimate.expectedSuccessfulIntercepts, format: .number.precision(.fractionLength(1))) of \(dailyEstimate.incomingCount)"
          )
          Text(
            "Expected leak-through: \(dailyEstimate.expectedLeakThrough, format: .number.precision(.fractionLength(1)))"
          )
          Text(
            "Expected shots consumed: \(dailyEstimate.expectedShotsConsumed, format: .number.precision(.fractionLength(1)))"
          )
          
          if dailyThreatCount > 0, dailyHits > 0 {
            let recordedDefenseRate = max(Double(dailyThreatCount - min(dailyHits, dailyThreatCount)), 0.0) / Double(dailyThreatCount)
            Text("Recorded defense rate from hits field: \(recordedDefenseRate, format: .percent.precision(.fractionLength(1)))")
            Text("Recorded leak-through hits: \(dailyHits)")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      
      if showMonteCarlo, let monteCarlo = result.monteCarlo {
        MonteCarloResultBlock(summary: monteCarlo)
      }
      
      if threats.count > 8 {
        Button(showPerThreatDetails ? "Hide per-threat allocation details" : "Show per-threat allocation details") {
          showPerThreatDetails.toggle()
        }
        .font(.caption)
      }
      
      if threats.count <= 8 || showPerThreatDetails {
        ForEach(Array(threats.enumerated()), id: \.element.id) { index, threat in
          VStack(alignment: .leading, spacing: 2) {
            HStack {
              Text(threat.name)
              Spacer()
              Text("\(result.allocation[index]) interceptors")
                .foregroundStyle(.secondary)
            }
            
            Text(
              "Kill probability: \(result.perThreatKillProbability[index], format: .number.precision(.fractionLength(3)))"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            
            Text(
              "Expected shots: \(result.perThreatExpectedShots[index], format: .number.precision(.fractionLength(2)))"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }
          .padding(.vertical, 2)
        }
      }
    }
    .padding(.vertical, 4)
  }
}

