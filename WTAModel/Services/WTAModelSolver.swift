import Foundation

struct WTAComputationInput: Sendable {
  let threats: [Threat]
  /// `nil` = no global interceptor budget (per-threat limits only).
  let totalInterceptors: Int?
  let doctrine: EngagementDoctrine
  let monteCarloSamples: Int
  let dailyThreatCount: Int
  let dailyPerThreatIncoming: [Int]
}

struct WTAComputationOutput: Sendable {
  let exactResult: AllocationResult?
  let greedyResult: AllocationResult?
  let exactDailyEstimate: DailyDefenseEstimate?
  let greedyDailyEstimate: DailyDefenseEstimate?
  let exactSolverNote: String?
}

/// Serializes WTA math off the main actor. Stateless per call; safe to share app-wide.
actor WTAModelSolver {
  static let shared = WTAModelSolver()
  
  func compute(_ input: WTAComputationInput) -> WTAComputationOutput {
    let threats = input.threats
    let totalInterceptors = input.totalInterceptors
    let doctrine = input.doctrine
    let monteCarloSamples = input.monteCarloSamples
    let dailyThreatCount = input.dailyThreatCount
    let dailyPerThreatIncoming = input.dailyPerThreatIncoming
    
    let shouldRunExact = ExactAllocator.shouldRunExactly(
      threatCount: threats.count,
      totalInterceptors: totalInterceptors
    )
    let estimatedStates = ExactAllocator.estimatedAllocationStates(
      threatCount: threats.count,
      totalInterceptors: totalInterceptors
    )
    
    let exactResult = shouldRunExact
    ? ExactAllocator.solve(
      threats: threats,
      totalInterceptors: totalInterceptors,
      doctrine: doctrine,
      monteCarloSamples: monteCarloSamples
    )
    : nil
    
    let greedyResult = GreedyAllocator.solve(
      threats: threats,
      totalInterceptors: totalInterceptors,
      doctrine: doctrine,
      monteCarloSamples: monteCarloSamples
    )
    
    let exactDailyEstimate = DailyDefenseEstimator.estimate(
      threats: threats,
      totalIncoming: dailyThreatCount,
      perThreatIncoming: dailyPerThreatIncoming,
      totalInterceptors: totalInterceptors,
      doctrine: doctrine,
      method: .exact
    )
    
    let greedyDailyEstimate = DailyDefenseEstimator.estimate(
      threats: threats,
      totalIncoming: dailyThreatCount,
      perThreatIncoming: dailyPerThreatIncoming,
      totalInterceptors: totalInterceptors,
      doctrine: doctrine,
      method: .greedy
    )
    
    let exactSolverNote: String?
    if shouldRunExact {
      exactSolverNote = nil
    } else if let totalInterceptors {
      exactSolverNote = Self.exactSolverSkippedMessage(
        threatCount: threats.count,
        totalInterceptors: totalInterceptors,
        estimatedStates: estimatedStates
      )
    } else {
      exactSolverNote = nil
    }
    
    return WTAComputationOutput(
      exactResult: exactResult,
      greedyResult: greedyResult,
      exactDailyEstimate: exactDailyEstimate,
      greedyDailyEstimate: greedyDailyEstimate,
      exactSolverNote: exactSolverNote
    )
  }
  
  private nonisolated static func exactSolverSkippedMessage(
    threatCount: Int,
    totalInterceptors: Int,
    estimatedStates: Double
  ) -> String {
    if estimatedStates.isFinite {
      return "Skipped exact solver for \(threatCount) threats and \(totalInterceptors) interceptors because it expands to about \(estimatedStates.formatted(.number.notation(.scientific))) allocations."
    }
    
    return "Skipped exact solver for \(threatCount) threats and \(totalInterceptors) interceptors because the allocation search space is too large."
  }
}

