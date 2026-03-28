import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class WTAViewModel {
  /// `nil` = no global cap on total interceptors (only per-threat limits apply).
  var totalInterceptors: Int? = 7
  var doctrine: EngagementDoctrine = .shootLookShoot
  var monteCarloSamples: Int = 400
  var dailyThreatCount: Int = 0
  var dailyHits: Int = 0
  var dailyPerThreatIncoming: [Int] = Array(repeating: 0, count: SampleData.defaultThreats.count)
  var dailyObservations: [DailyObservation] = []
  var selectedObservationDate: Date = Calendar.current.startOfDay(for: Date())
  var threats: [Threat] = SampleData.defaultThreats
  
  private(set) var isComputing = false
  private(set) var exactSolverNote: String?
  private(set) var exactDailyEstimate: DailyDefenseEstimate?
  private(set) var exactResult: AllocationResult?
  private(set) var greedyDailyEstimate: DailyDefenseEstimate?
  private(set) var greedyResult: AllocationResult?
  
  private var recomputeGeneration = 0
  private var recomputeTask: Task<Void, Never>?
  
  init() {
    dailyObservations = DailyObservationsPersistence.load()
    recompute()
  }
  
  func recompute() {
    recomputeTask?.cancel()
    recomputeGeneration += 1
    let generation = recomputeGeneration
    
    enforcePerThreatCapsSumAtMostGlobalBudget()
    
    let input = WTAComputationInput(
      threats: threats,
      totalInterceptors: totalInterceptors,
      doctrine: doctrine,
      monteCarloSamples: monteCarloSamples,
      dailyThreatCount: dailyThreatCount,
      dailyPerThreatIncoming: dailyPerThreatIncoming
    )
    
    exactSolverNote = nil
    isComputing = true
    
    recomputeTask = Task { @MainActor in
      let output = await WTAModelSolver.shared.compute(input)
      guard !Task.isCancelled else { return }
      guard generation == self.recomputeGeneration else { return }
      self.exactResult = output.exactResult
      self.exactDailyEstimate = output.exactDailyEstimate
      self.greedyResult = output.greedyResult
      self.greedyDailyEstimate = output.greedyDailyEstimate
      self.exactSolverNote = output.exactSolverNote
      self.isComputing = false
    }
  }
  
  func addThreat() {
    threats.append(SampleData.generatedThreat(index: threats.count))
    dailyPerThreatIncoming.append(0)
    recompute()
  }
  
  func removeThreat(at offsets: IndexSet) {
    threats.remove(atOffsets: offsets)
    dailyPerThreatIncoming.remove(atOffsets: offsets)
    recompute()
  }
  
  func reset() {
    loadScenario(SampleData.defaultScenario)
  }
  
  func loadScenario(_ scenario: Scenario) {
    let normalizedThreats = normalizedThreatCatalog(scenario.threats)
    
    totalInterceptors = scenario.totalInterceptors
    doctrine = scenario.doctrine
    monteCarloSamples = scenario.monteCarloSamples
    dailyThreatCount = scenario.dailyThreatCount
    dailyHits = scenario.dailyHits
    dailyPerThreatIncoming = normalizedDailyPerThreatIncoming(
      scenario.dailyPerThreatIncoming,
      threatCount: normalizedThreats.count
    )
    dailyObservations = scenario.dailyObservations.sorted { $0.date < $1.date }
    threats = normalizedThreats.map { normalizedThreat($0, totalInterceptors: totalInterceptors) }
    persistDailyObservations()
    recompute()
  }
  
  func applyScenarioCounts(incomingCount: Int, totalInterceptors: Int?) {
    let normalizedIncomingCount = max(incomingCount, 0)
    let normalizedBudget = totalInterceptors.map { max($0, 0) }
    let normalizedThreats = normalizedThreatCatalog(threats)
    let perThreatTotal = dailyPerThreatIncoming.reduce(0, +)
    
    self.totalInterceptors = normalizedBudget
    threats = normalizedThreats.map { normalizedThreat($0, totalInterceptors: normalizedBudget) }
    dailyThreatCount = max(normalizedIncomingCount, perThreatTotal)
    
    dailyPerThreatIncoming = normalizedDailyPerThreatIncoming(
      dailyPerThreatIncoming,
      threatCount: threats.count
    )
    dailyHits = min(dailyHits, dailyThreatCount)
    
    recompute()
  }
  
  /// Updates the global interceptor budget from the Interceptor count field (empty = limitless). Reclamps per-threat caps and recomputes.
  func applyInterceptorBudget(_ budget: Int?) {
    let normalized = budget.map { max(0, $0) }
    guard normalized != totalInterceptors else { return }
    
    totalInterceptors = normalized
    threats = normalizedThreatCatalog(threats).map { normalizedThreat($0, totalInterceptors: normalized) }
    recompute()
  }
  
  func applyDailyAnalysis(threatCount: Int, hits: Int, perThreatIncoming: [Int]) {
    let normalizedPerThreatIncoming = normalizedDailyPerThreatIncoming(
      perThreatIncoming,
      threatCount: threats.count
    )
    let perThreatTotal = normalizedPerThreatIncoming.reduce(0, +)
    let normalizedThreatCount = max(max(threatCount, 0), perThreatTotal)
    
    dailyThreatCount = normalizedThreatCount
    dailyHits = min(max(hits, 0), normalizedThreatCount)
    dailyPerThreatIncoming = normalizedPerThreatIncoming
    recompute()
  }
  
  func saveCurrentDailyObservation() {
    guard dailyThreatCount > 0 else { return }
    
    let calculationSnapshot: DailyCalculationSnapshot? = greedyResult.map { greedy in
      DailyCalculationSnapshot(
        savedThreats: threats.map { SavedThreatStub(id: $0.id, name: $0.name) },
        totalInterceptors: totalInterceptors,
        monteCarloSamples: monteCarloSamples,
        exactResult: exactResult,
        greedyResult: greedy,
        exactDailyEstimate: exactDailyEstimate,
        greedyDailyEstimate: greedyDailyEstimate
      )
    }
    
    let observation = DailyObservation(
      date: Calendar.current.startOfDay(for: selectedObservationDate),
      totalIncoming: dailyThreatCount,
      totalHits: dailyHits,
      perThreatIncoming: zip(threats, dailyPerThreatIncoming).map { threat, incomingCount in
        DailyThreatObservation(
          threatID: threat.id,
          threatName: threat.name,
          incomingCount: max(incomingCount, 0)
        )
      },
      calculationSnapshot: calculationSnapshot
    )
    
    if let existingIndex = dailyObservations.firstIndex(where: {
      Calendar.current.isDate($0.date, inSameDayAs: observation.date)
    }) {
      dailyObservations[existingIndex] = observation
    } else {
      dailyObservations.append(observation)
      dailyObservations.sort { $0.date < $1.date }
    }
    
    persistDailyObservations()
  }
  
  func removeDailyObservations(at offsets: IndexSet) {
    dailyObservations.remove(atOffsets: offsets)
    persistDailyObservations()
  }
  
  private func persistDailyObservations() {
    let snapshot = dailyObservations
    Task {
      await DailyJournalSaveActor.shared.save(snapshot)
    }
  }
  
  var threatForecasts: [ThreatForecast] {
    TimeSeriesForecaster.forecasts(observations: dailyObservations)
  }
  
  var scenario: Scenario {
    Scenario(
      totalInterceptors: totalInterceptors,
      doctrine: doctrine,
      monteCarloSamples: monteCarloSamples,
      dailyThreatCount: dailyThreatCount,
      dailyHits: dailyHits,
      dailyPerThreatIncoming: dailyPerThreatIncoming,
      dailyObservations: dailyObservations,
      threats: threats
    )
  }
  
  /// Sum of explicit per-threat interceptor limits (threats without a limit contribute 0 here).
  var sumOfPerThreatInterceptorCaps: Int {
    threats.compactMap(\.maxAssignedInterceptors).reduce(0, +)
  }
  
  /// How many interceptors this threat may have in its personal cap while respecting others’ caps and the global budget `G`.
  func residualBudgetForPerThreatCap(excludingThreatID id: UUID) -> Int {
    guard let globalBudget = totalInterceptors else { return Int.max }
    let sumOthers = threats.filter { $0.id != id }.compactMap(\.maxAssignedInterceptors).reduce(0, +)
    return max(0, globalBudget - sumOthers)
  }
  
  /// Ensures Σ (per-threat limits) ≤ global budget whenever a budget is set.
  private func enforcePerThreatCapsSumAtMostGlobalBudget() {
    guard let globalBudget = totalInterceptors, globalBudget >= 0 else { return }
    
    let cappedIndices = threats.indices.filter { threats[$0].maxAssignedInterceptors != nil }
    let sumCaps = cappedIndices.compactMap { threats[$0].maxAssignedInterceptors }.reduce(0, +)
    guard sumCaps > globalBudget else { return }
    
    let sortedByCap = cappedIndices.sorted {
      (threats[$0].maxAssignedInterceptors ?? 0) > (threats[$1].maxAssignedInterceptors ?? 0)
    }
    
    var remaining = globalBudget
    for index in sortedByCap {
      let current = threats[index].maxAssignedInterceptors ?? 0
      let newCap = min(current, remaining)
      threats[index].maxAssignedInterceptors = newCap > 0 ? newCap : nil
      remaining -= newCap
    }
  }
  
  private func normalizedDailyPerThreatIncoming(_ values: [Int], threatCount: Int) -> [Int] {
    var normalized = Array(values.prefix(threatCount)).map { max($0, 0) }
    
    if normalized.count < threatCount {
      normalized.append(contentsOf: Array(repeating: 0, count: threatCount - normalized.count))
    }
    
    return normalized
  }
  
  private func normalizedThreatCatalog(_ threats: [Threat]) -> [Threat] {
    guard isAutoGeneratedThreatExpansion(threats) else { return threats }
    return Array(threats.prefix(SampleData.defaultThreats.count))
  }
  
  private func normalizedThreat(_ threat: Threat, totalInterceptors: Int?) -> Threat {
    var normalizedThreat = threat
    
    if let cap = totalInterceptors, let maxAssigned = normalizedThreat.maxAssignedInterceptors {
      normalizedThreat.maxAssignedInterceptors = min(max(maxAssigned, 0), cap)
    } else if let maxAssigned = normalizedThreat.maxAssignedInterceptors {
      normalizedThreat.maxAssignedInterceptors = max(maxAssigned, 0)
    }
    
    return normalizedThreat
  }
  
  private func isAutoGeneratedThreatExpansion(_ threats: [Threat]) -> Bool {
    guard threats.count > SampleData.defaultThreats.count else { return false }
    
    let defaultPrefix = Array(threats.prefix(SampleData.defaultThreats.count))
    let matchesDefaultPrefix = zip(defaultPrefix, SampleData.defaultThreats).allSatisfy { current, expected in
      current.name == expected.name
    }
    
    guard matchesDefaultPrefix else { return false }
    
    return threats.dropFirst(SampleData.defaultThreats.count).enumerated().allSatisfy { offset, threat in
      threat.name == "Threat \(offset + SampleData.defaultThreats.count + 1)"
    }
  }
}

enum SampleData {
  static let defaultThreats: [Threat] = [
    Threat(
      name: "City",
      value: 1000,
      baseShotProbability: 0.62,
      followOnDecay: 0.03,
      pTrack: 0.90,
      uncertainty: 0.05
    ),
    Threat(
      name: "Airport",
      value: 400,
      baseShotProbability: 0.56,
      followOnDecay: 0.02,
      pTrack: 0.95,
      uncertainty: 0.04
    ),
    Threat(
      name: "Base",
      value: 600,
      baseShotProbability: 0.59,
      followOnDecay: 0.025,
      pTrack: 0.92,
      uncertainty: 0.05
    )
  ]
  
  static let defaultScenario = Scenario(
    totalInterceptors: 7,
    doctrine: .shootLookShoot,
    monteCarloSamples: 400,
    dailyThreatCount: 0,
    dailyHits: 0,
    dailyPerThreatIncoming: Array(repeating: 0, count: defaultThreats.count),
    dailyObservations: [],
    threats: defaultThreats
  )
  
  static func generatedThreat(index: Int) -> Threat {
    let template = defaultThreats[index % defaultThreats.count]
    return Threat(
      name: "Threat \(index + 1)",
      value: template.value,
      baseShotProbability: template.baseShotProbability,
      followOnDecay: template.followOnDecay,
      pTrack: template.pTrack,
      uncertainty: template.uncertainty
    )
  }
}

