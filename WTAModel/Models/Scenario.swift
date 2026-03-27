import Foundation

struct Scenario: Codable, Equatable {
    /// Global interceptor budget shared across threats. `nil` means no cap (assign until marginal gain ends; per-threat caps still apply).
    var totalInterceptors: Int?
    var doctrine: EngagementDoctrine
    var monteCarloSamples: Int
    var dailyThreatCount: Int
    var dailyHits: Int
    var dailyPerThreatIncoming: [Int]
    var dailyObservations: [DailyObservation]
    var threats: [Threat]

    init(
        totalInterceptors: Int?,
        doctrine: EngagementDoctrine,
        monteCarloSamples: Int,
        dailyThreatCount: Int,
        dailyHits: Int,
        dailyPerThreatIncoming: [Int],
        dailyObservations: [DailyObservation],
        threats: [Threat]
    ) {
        self.totalInterceptors = totalInterceptors
        self.doctrine = doctrine
        self.monteCarloSamples = monteCarloSamples
        self.dailyThreatCount = dailyThreatCount
        self.dailyHits = dailyHits
        self.dailyPerThreatIncoming = dailyPerThreatIncoming
        self.dailyObservations = dailyObservations
        self.threats = threats
    }
}

extension Scenario {
    enum CodingKeys: String, CodingKey {
        case totalInterceptors
        case doctrine
        case monteCarloSamples
        case dailyThreatCount
        case dailyHits
        case dailyPerThreatIncoming
        case dailyObservations
        case threats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.totalInterceptors) {
            if try container.decodeNil(forKey: .totalInterceptors) {
                totalInterceptors = nil
            } else {
                totalInterceptors = try container.decode(Int.self, forKey: .totalInterceptors)
            }
        } else {
            totalInterceptors = 7
        }

        doctrine = try container.decodeIfPresent(EngagementDoctrine.self, forKey: .doctrine) ?? .salvo
        monteCarloSamples = try container.decodeIfPresent(Int.self, forKey: .monteCarloSamples) ?? 400
        dailyThreatCount = try container.decodeIfPresent(Int.self, forKey: .dailyThreatCount) ?? 0
        dailyHits = try container.decodeIfPresent(Int.self, forKey: .dailyHits) ?? 0
        dailyPerThreatIncoming = try container.decodeIfPresent([Int].self, forKey: .dailyPerThreatIncoming) ?? []
        dailyObservations = try container.decodeIfPresent([DailyObservation].self, forKey: .dailyObservations) ?? []
        threats = try container.decode([Threat].self, forKey: .threats)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let totalInterceptors {
            try container.encode(totalInterceptors, forKey: .totalInterceptors)
        } else {
            try container.encodeNil(forKey: .totalInterceptors)
        }
        try container.encode(doctrine, forKey: .doctrine)
        try container.encode(monteCarloSamples, forKey: .monteCarloSamples)
        try container.encode(dailyThreatCount, forKey: .dailyThreatCount)
        try container.encode(dailyHits, forKey: .dailyHits)
        try container.encode(dailyPerThreatIncoming, forKey: .dailyPerThreatIncoming)
        try container.encode(dailyObservations, forKey: .dailyObservations)
        try container.encode(threats, forKey: .threats)
    }
}
