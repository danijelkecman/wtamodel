import Foundation

struct MonteCarloSummary: Equatable, Codable {
  let samples: Int
  let meanExpectedValue: Double
  let p10ExpectedValue: Double
  let p90ExpectedValue: Double
  let meanExpectedShots: Double
}

struct DailyDefenseEstimate: Equatable, Codable {
  let incomingCount: Int
  let successRate: Double
  let expectedSuccessfulIntercepts: Double
  let expectedLeakThrough: Double
  let expectedShotsConsumed: Double
}

struct AllocationResult: Equatable, Codable {
  let allocation: [Int]
  let totalExpectedValue: Double
  let perThreatKillProbability: [Double]
  let perThreatExpectedShots: [Double]
  let totalExpectedShots: Double
  let method: String
  let doctrine: EngagementDoctrine
  let monteCarlo: MonteCarloSummary?
}

