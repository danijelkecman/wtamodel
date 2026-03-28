import Foundation

enum DefenseMath {
  static func killProbability(shotProbabilities: [Double]) -> Double {
    for probability in shotProbabilities {
      precondition((0.0...1.0).contains(probability), "shot probabilities must be in [0, 1]")
    }
    
    guard !shotProbabilities.isEmpty else { return 0.0 }
    
    let missProbability = shotProbabilities.reduce(1.0) { partialResult, probability in
      partialResult * (1.0 - probability)
    }
    
    return 1.0 - missProbability
  }
  
  static func effectiveKillProbability(shotProbabilities: [Double], pTrack: Double) -> Double {
    precondition((0.0...1.0).contains(pTrack), "pTrack must be in [0, 1]")
    return pTrack * killProbability(shotProbabilities: shotProbabilities)
  }
  
  static func expectedShotsConsumed(
    shotProbabilities: [Double],
    pTrack: Double,
    doctrine: EngagementDoctrine
  ) -> Double {
    precondition((0.0...1.0).contains(pTrack), "pTrack must be in [0, 1]")
    
    guard !shotProbabilities.isEmpty else { return 0.0 }
    
    switch doctrine {
    case .salvo:
      return pTrack * Double(shotProbabilities.count)
    case .shootLookShoot:
      var expectedShotsGivenTrack = 0.0
      var probabilityThreatSurvivesToNextShot = 1.0
      
      for probability in shotProbabilities {
        expectedShotsGivenTrack += probabilityThreatSurvivesToNextShot
        probabilityThreatSurvivesToNextShot *= (1.0 - probability)
      }
      
      return pTrack * expectedShotsGivenTrack
    }
  }
  
  static func marginalGain(threat: Threat, currentInterceptors: Int) -> Double {
    let beforeProbabilities = threat.shotProbabilities(maxInterceptors: currentInterceptors)
    let afterProbabilities = threat.shotProbabilities(maxInterceptors: currentInterceptors + 1)
    
    let before = threat.value * effectiveKillProbability(
      shotProbabilities: beforeProbabilities,
      pTrack: threat.pTrack
    )
    let after = threat.value * effectiveKillProbability(
      shotProbabilities: afterProbabilities,
      pTrack: threat.pTrack
    )
    
    return after - before
  }
  
  /// Shots to assign to this threat when there is no shared interceptor budget (stops at zero marginal gain or per-threat cap).
  static func independentOptimalInterceptorCount(for threat: Threat) -> Int {
    let cap = threat.maxAssignedInterceptors ?? 10_000
    var count = 0
    while count < cap {
      let gain = marginalGain(threat: threat, currentInterceptors: count)
      if !gain.isFinite || gain <= 0 { break }
      count += 1
    }
    return count
  }
  
  /// Upper range for marginal-gain charts: respects global cap when set, otherwise per-threat saturation.
  static func chartInterceptorDisplayMax(threats: [Threat], globalInterceptorBudget: Int?) -> Int {
    let saturationPeak = threats.map { max(independentOptimalInterceptorCount(for: $0), 1) }.max() ?? 1
    if let budget = globalInterceptorBudget {
      return max(budget, saturationPeak, 1)
    }
    return max(saturationPeak, 1)
  }
}
