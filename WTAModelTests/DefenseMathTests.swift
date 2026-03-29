import XCTest
@testable import WTAModel

final class DefenseMathTests: XCTestCase {
  func testEffectiveKillProbabilityMatchesIndependentShotFormula() {
    let probabilities = [0.6, 0.4]
    let result = DefenseMath.effectiveKillProbability(shotProbabilities: probabilities, pTrack: 0.8)
    
    XCTAssertEqual(result, 0.608, accuracy: 0.000_001)
  }
  
  func testShootLookShootConsumesFewerExpectedShotsThanSalvo() {
    let probabilities = [0.5, 0.25, 0.25]
    
    let salvo = DefenseMath.expectedShotsConsumed(
      shotProbabilities: probabilities,
      pTrack: 0.9,
      doctrine: .salvo
    )
    let shootLookShoot = DefenseMath.expectedShotsConsumed(
      shotProbabilities: probabilities,
      pTrack: 0.9,
      doctrine: .shootLookShoot
    )
    
    XCTAssertEqual(salvo, 2.7, accuracy: 0.000_001)
    XCTAssertEqual(shootLookShoot, 1.6875, accuracy: 0.000_001)
    XCTAssertLessThan(shootLookShoot, salvo)
  }
  
  func testIndependentOptimalInterceptorCountStopsAtPerThreatCap() {
    let threat = Threat(
      name: "Bounded",
      value: 100,
      baseShotProbability: 0.7,
      followOnDecay: 0.1,
      pTrack: 0.95,
      uncertainty: 0.02,
      maxAssignedInterceptors: 2
    )
    
    XCTAssertEqual(DefenseMath.independentOptimalInterceptorCount(for: threat), 2)
  }
}
