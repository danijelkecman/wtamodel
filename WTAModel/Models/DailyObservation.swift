import Foundation

struct SavedThreatStub: Codable, Equatable, Identifiable {
  let id: UUID
  var name: String
}

/// Captures WTA outputs at the moment a daily entry is saved (for history and cold-load display).
struct DailyCalculationSnapshot: Codable, Equatable {
  var savedThreats: [SavedThreatStub]
  /// `nil` if saved with no global interceptor budget.
  var totalInterceptors: Int?
  var monteCarloSamples: Int
  var exactResult: AllocationResult?
  var greedyResult: AllocationResult
  var exactDailyEstimate: DailyDefenseEstimate?
  var greedyDailyEstimate: DailyDefenseEstimate?
}

struct DailyThreatObservation: Codable, Equatable, Identifiable {
  let id: UUID
  var threatID: UUID
  var threatName: String
  var incomingCount: Int
  
  init(id: UUID = UUID(), threatID: UUID, threatName: String, incomingCount: Int) {
    self.id = id
    self.threatID = threatID
    self.threatName = threatName
    self.incomingCount = incomingCount
  }
}

struct DailyObservation: Codable, Equatable, Identifiable {
  let id: UUID
  var date: Date
  var totalIncoming: Int
  var totalHits: Int
  var perThreatIncoming: [DailyThreatObservation]
  /// Present for entries saved after this feature: stores solver outputs and defense posture at save time.
  var calculationSnapshot: DailyCalculationSnapshot?
  
  init(
    id: UUID = UUID(),
    date: Date,
    totalIncoming: Int,
    totalHits: Int,
    perThreatIncoming: [DailyThreatObservation],
    calculationSnapshot: DailyCalculationSnapshot? = nil
  ) {
    self.id = id
    self.date = date
    self.totalIncoming = totalIncoming
    self.totalHits = totalHits
    self.perThreatIncoming = perThreatIncoming
    self.calculationSnapshot = calculationSnapshot
  }
  
  var successfulDefenses: Int {
    max(totalIncoming - totalHits, 0)
  }
  
  var observedThreatCount: Int {
    perThreatIncoming.count
  }
  
  func incomingCount(for threat: Threat) -> Int {
    if let exactMatch = perThreatIncoming.first(where: { $0.threatID == threat.id }) {
      return exactMatch.incomingCount
    }
    
    return perThreatIncoming.first(where: { $0.threatName == threat.name })?.incomingCount ?? 0
  }
  
  func incomingCount(forThreatNamed threatName: String) -> Int {
    perThreatIncoming
      .filter { $0.threatName == threatName }
      .reduce(0) { partialResult, observation in
        partialResult + observation.incomingCount
      }
  }
  
  var perThreatIncomingSummary: String {
    perThreatIncoming
      .map { "\($0.threatName): \($0.incomingCount)" }
      .joined(separator: ", ")
  }
}

struct ThreatForecast: Identifiable, Equatable {
  var id: String { threatName }
  
  let threatName: String
  let predictedIncomingCount: Double
  let recentAverage: Double
  let trendPerDay: Double
  let sampleCount: Int
}

