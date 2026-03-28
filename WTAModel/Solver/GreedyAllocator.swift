import Foundation

enum GreedyAllocator {
  /// `totalInterceptors == nil` means no global cap: assign until no positive marginal gain (per-threat caps still apply).
  static func solve(
    threats: [Threat],
    totalInterceptors: Int?,
    doctrine: EngagementDoctrine,
    monteCarloSamples: Int
  ) -> AllocationResult? {
    guard !threats.isEmpty else { return nil }
    if let totalInterceptors, totalInterceptors < 0 { return nil }
    
    var allocation = Array(repeating: 0, count: threats.count)
    
    if let totalInterceptors {
      for _ in 0..<totalInterceptors {
        guard assignNextGreedyStep(threats: threats, allocation: &allocation) else { break }
      }
    } else {
      while assignNextGreedyStep(threats: threats, allocation: &allocation) {}
    }
    
    return AllocationEvaluator.evaluate(
      threats: threats,
      allocation: allocation,
      method: "Greedy",
      doctrine: doctrine,
      monteCarloSamples: monteCarloSamples
    )
  }
  
  @discardableResult
  private static func assignNextGreedyStep(threats: [Threat], allocation: inout [Int]) -> Bool {
    var bestIndex = 0
    var bestGain = -Double.infinity
    
    for index in threats.indices {
      if let maxAssignedInterceptors = threats[index].maxAssignedInterceptors,
         allocation[index] >= maxAssignedInterceptors {
        continue
      }
      
      let gain = DefenseMath.marginalGain(
        threat: threats[index],
        currentInterceptors: allocation[index]
      )
      if gain > bestGain {
        bestGain = gain
        bestIndex = index
      }
    }
    
    guard bestGain.isFinite, bestGain > 0 else { return false }
    allocation[bestIndex] += 1
    return true
  }
}
