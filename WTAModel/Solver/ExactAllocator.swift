import Foundation

enum ExactAllocator {
  nonisolated static let defaultMaxAllocationStates = 250_000.0
  
  /// `totalInterceptors == nil` means no global cap: each threat gets its independent optimal count (no shared budget).
  nonisolated static func solve(
    threats: [Threat],
    totalInterceptors: Int?,
    doctrine: EngagementDoctrine,
    monteCarloSamples: Int
  ) -> AllocationResult? {
    guard !threats.isEmpty else { return nil }
    
    if totalInterceptors == nil {
      let allocation = threats.map { DefenseMath.independentOptimalInterceptorCount(for: $0) }
      return AllocationEvaluator.evaluate(
        threats: threats,
        allocation: allocation,
        method: "Exact",
        doctrine: doctrine,
        monteCarloSamples: monteCarloSamples
      )
    }
    
    guard let totalInterceptors, totalInterceptors >= 0 else { return nil }
    
    var best: AllocationResult?
    var current = Array(repeating: 0, count: threats.count)
    
    func search(index: Int, remaining: Int) {
      let maxAssignableHere = min(remaining, threats[index].maxAssignedInterceptors ?? remaining)
      
      if index == threats.count - 1 {
        guard remaining <= maxAssignableHere else { return }
        current[index] = remaining
        let candidate = AllocationEvaluator.evaluate(
          threats: threats,
          allocation: current,
          method: "Exact",
          doctrine: doctrine
        )
        
        if let best, candidate.totalExpectedValue <= best.totalExpectedValue {
          return
        }
        
        best = candidate
        return
      }
      
      for assigned in 0...maxAssignableHere {
        current[index] = assigned
        search(index: index + 1, remaining: remaining - assigned)
      }
    }
    
    search(index: 0, remaining: totalInterceptors)
    
    guard let best else { return nil }
    
    return AllocationEvaluator.evaluate(
      threats: threats,
      allocation: best.allocation,
      method: "Exact",
      doctrine: doctrine,
      monteCarloSamples: monteCarloSamples
    )
  }
  
  nonisolated static func estimatedAllocationStates(
    threatCount: Int,
    totalInterceptors: Int?
  ) -> Double {
    guard let totalInterceptors, threatCount > 0, totalInterceptors >= 0 else { return 0 }
    guard threatCount > 1, totalInterceptors > 0 else { return 1 }
    
    let n = totalInterceptors + threatCount - 1
    let k = min(totalInterceptors, threatCount - 1)
    var result = 1.0
    
    for step in 1...k {
      result *= Double(n - k + step)
      result /= Double(step)
      
      if !result.isFinite {
        return .infinity
      }
    }
    
    return result
  }
  
  nonisolated static func shouldRunExactly(
    threatCount: Int,
    totalInterceptors: Int?,
    maxAllocationStates: Double = defaultMaxAllocationStates
  ) -> Bool {
    guard let totalInterceptors else { return true }
    return estimatedAllocationStates(
      threatCount: threatCount,
      totalInterceptors: totalInterceptors
    ) <= maxAllocationStates
  }
}
