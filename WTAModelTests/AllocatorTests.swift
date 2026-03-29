import XCTest
@testable import WTAModel

final class AllocatorTests: XCTestCase {
  func testExactAllocatorBeatsOrMatchesGreedyOnSharedBudget() throws {
    let threats = [
      Threat(name: "High", value: 120, baseShotProbability: 0.7, followOnDecay: 0.15, pTrack: 0.9, uncertainty: 0.02),
      Threat(name: "Medium", value: 80, baseShotProbability: 0.6, followOnDecay: 0.05, pTrack: 0.95, uncertainty: 0.02),
      Threat(name: "Low", value: 60, baseShotProbability: 0.45, followOnDecay: 0.02, pTrack: 0.85, uncertainty: 0.02)
    ]
    
    let exact = try XCTUnwrap(
      ExactAllocator.solve(
        threats: threats,
        totalInterceptors: 3,
        doctrine: .shootLookShoot,
        monteCarloSamples: 0
      )
    )
    let greedy = try XCTUnwrap(
      GreedyAllocator.solve(
        threats: threats,
        totalInterceptors: 3,
        doctrine: .shootLookShoot,
        monteCarloSamples: 0
      )
    )
    
    XCTAssertGreaterThanOrEqual(exact.totalExpectedValue, greedy.totalExpectedValue)
    XCTAssertEqual(exact.allocation.reduce(0, +), 3)
    XCTAssertEqual(greedy.allocation.reduce(0, +), 3)
  }
  
  func testExactAllocatorWithoutGlobalBudgetUsesIndependentOptima() throws {
    let threats = [
      Threat(name: "A", value: 100, baseShotProbability: 0.5, followOnDecay: 0.5, pTrack: 1.0, uncertainty: 0.0),
      Threat(name: "B", value: 100, baseShotProbability: 0.4, followOnDecay: 0.4, pTrack: 1.0, uncertainty: 0.0, maxAssignedInterceptors: 1)
    ]
    
    let result = try XCTUnwrap(
      ExactAllocator.solve(
        threats: threats,
        totalInterceptors: nil,
        doctrine: .salvo,
        monteCarloSamples: 0
      )
    )
    
    XCTAssertEqual(result.allocation, [1, 1])
  }
}
