import Foundation

enum AllocationEvaluator {
  nonisolated static func evaluate(
    threats: [Threat],
    allocation: [Int],
    method: String,
    doctrine: EngagementDoctrine,
    monteCarloSamples: Int = 0
  ) -> AllocationResult {
    precondition(threats.count == allocation.count, "Allocation count must match threat count")
    
    var total = 0.0
    var probabilities: [Double] = []
    var expectedShots: [Double] = []
    
    for (threat, count) in zip(threats, allocation) {
      let shotProbabilities = threat.shotProbabilities(maxInterceptors: count)
      let pKill = DefenseMath.effectiveKillProbability(
        shotProbabilities: shotProbabilities,
        pTrack: threat.pTrack
      )
      let shotsConsumed = DefenseMath.expectedShotsConsumed(
        shotProbabilities: shotProbabilities,
        pTrack: threat.pTrack,
        doctrine: doctrine
      )
      
      probabilities.append(pKill)
      expectedShots.append(shotsConsumed)
      total += threat.value * pKill
    }
    
    return AllocationResult(
      allocation: allocation,
      totalExpectedValue: total,
      perThreatKillProbability: probabilities,
      perThreatExpectedShots: expectedShots,
      totalExpectedShots: expectedShots.reduce(0.0, +),
      method: method,
      doctrine: doctrine,
      monteCarlo: MonteCarloSimulator.summarize(
        threats: threats,
        allocation: allocation,
        doctrine: doctrine,
        samples: monteCarloSamples
      )
    )
  }
}
