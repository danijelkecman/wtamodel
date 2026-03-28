import Foundation

struct Threat: Identifiable, Hashable, Codable {
  let id: UUID
  var name: String
  var value: Double
  var baseShotProbability: Double
  var followOnDecay: Double
  var pTrack: Double
  var uncertainty: Double
  var maxAssignedInterceptors: Int?
  
  init(
    id: UUID = UUID(),
    name: String,
    value: Double,
    baseShotProbability: Double,
    followOnDecay: Double,
    pTrack: Double,
    uncertainty: Double,
    maxAssignedInterceptors: Int? = nil
  ) {
    self.id = id
    self.name = name
    self.value = value
    self.baseShotProbability = baseShotProbability
    self.followOnDecay = followOnDecay
    self.pTrack = pTrack
    self.uncertainty = uncertainty
    self.maxAssignedInterceptors = maxAssignedInterceptors
  }
  
  func shotProbabilities(maxInterceptors: Int) -> [Double] {
    guard maxInterceptors > 0 else { return [] }
    
    return (0..<maxInterceptors).map { shotIndex in
      shotProbability(at: shotIndex)
    }
  }
  
  func shotProbability(at shotIndex: Int) -> Double {
    precondition(shotIndex >= 0, "shotIndex must be >= 0")
    return Self.clampProbability(baseShotProbability - (Double(shotIndex) * followOnDecay))
  }
  
  private static func clampProbability(_ value: Double) -> Double {
    min(max(value, 0.0), 1.0)
  }
}

extension Threat {
  /// Minimal row for displaying a persisted allocation (name only; parameters are unused by result rows).
  static func displayStub(id: UUID, name: String) -> Threat {
    Threat(
      id: id,
      name: name,
      value: 1,
      baseShotProbability: 0,
      followOnDecay: 0,
      pTrack: 1,
      uncertainty: 0
    )
  }
  
  enum CodingKeys: String, CodingKey {
    case id
    case name
    case value
    case baseShotProbability
    case followOnDecay
    case pTrack
    case uncertainty
    case maxAssignedInterceptors
    case sspk
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    name = try container.decode(String.self, forKey: .name)
    value = try container.decode(Double.self, forKey: .value)
    if let baseShotProbability = try container.decodeIfPresent(Double.self, forKey: .baseShotProbability) {
      self.baseShotProbability = baseShotProbability
    } else {
      self.baseShotProbability = try container.decode(Double.self, forKey: .sspk)
    }
    followOnDecay = try container.decodeIfPresent(Double.self, forKey: .followOnDecay) ?? 0.03
    pTrack = try container.decode(Double.self, forKey: .pTrack)
    uncertainty = try container.decodeIfPresent(Double.self, forKey: .uncertainty) ?? 0.05
    maxAssignedInterceptors = try container.decodeIfPresent(Int.self, forKey: .maxAssignedInterceptors)
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encode(value, forKey: .value)
    try container.encode(baseShotProbability, forKey: .baseShotProbability)
    try container.encode(followOnDecay, forKey: .followOnDecay)
    try container.encode(pTrack, forKey: .pTrack)
    try container.encode(uncertainty, forKey: .uncertainty)
    try container.encodeIfPresent(maxAssignedInterceptors, forKey: .maxAssignedInterceptors)
  }
}

