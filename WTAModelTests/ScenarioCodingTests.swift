import XCTest
@testable import WTAModel

final class ScenarioCodingTests: XCTestCase {
  func testLegacyScenarioDecodingAppliesCompatibilityDefaults() throws {
    let json = """
    {
      "threats": [
        {
          "name": "Legacy",
          "value": 100,
          "sspk": 0.55,
          "pTrack": 0.9
        }
      ]
    }
    """.data(using: .utf8)!
    
    let scenario = try JSONDecoder().decode(Scenario.self, from: json)
    
    XCTAssertEqual(scenario.totalInterceptors, 7)
    XCTAssertEqual(scenario.doctrine, .salvo)
    XCTAssertEqual(scenario.monteCarloSamples, 400)
    XCTAssertEqual(scenario.threats.first?.baseShotProbability, 0.55)
    XCTAssertEqual(scenario.threats.first?.followOnDecay, 0.03)
    XCTAssertEqual(scenario.threats.first?.uncertainty, 0.05)
  }
  
  func testScenarioRoundTripsNilInterceptorBudget() throws {
    let scenario = Scenario(
      totalInterceptors: nil,
      doctrine: .shootLookShoot,
      monteCarloSamples: 100,
      dailyThreatCount: 5,
      dailyHits: 1,
      dailyPerThreatIncoming: [2, 3],
      dailyObservations: [],
      threats: [
        Threat(name: "City", value: 1000, baseShotProbability: 0.62, followOnDecay: 0.03, pTrack: 0.9, uncertainty: 0.05)
      ]
    )
    
    let data = try JSONEncoder().encode(scenario)
    let decoded = try JSONDecoder().decode(Scenario.self, from: data)
    
    XCTAssertNil(decoded.totalInterceptors)
    XCTAssertEqual(decoded.doctrine, .shootLookShoot)
    XCTAssertEqual(decoded.dailyThreatCount, 5)
  }
}
