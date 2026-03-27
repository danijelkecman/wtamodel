import Foundation

enum MonteCarloSimulator {
    static func summarize(
        threats: [Threat],
        allocation: [Int],
        doctrine: EngagementDoctrine,
        samples: Int
    ) -> MonteCarloSummary? {
        guard samples > 0, threats.count == allocation.count else { return nil }

        var defendedValues: [Double] = []
        var expectedShots: [Double] = []
        defendedValues.reserveCapacity(samples)
        expectedShots.reserveCapacity(samples)

        for _ in 0..<samples {
            var totalDefendedValue = 0.0
            var totalShotsConsumed = 0.0

            for (threat, interceptors) in zip(threats, allocation) {
                let sampledTrack = sampleProbability(
                    baseline: threat.pTrack,
                    uncertainty: threat.uncertainty
                )
                let sampledShots = threat
                    .shotProbabilities(maxInterceptors: interceptors)
                    .map { sampleProbability(baseline: $0, uncertainty: threat.uncertainty) }
                let killProbability = DefenseMath.effectiveKillProbability(
                    shotProbabilities: sampledShots,
                    pTrack: sampledTrack
                )

                totalDefendedValue += threat.value * killProbability
                totalShotsConsumed += DefenseMath.expectedShotsConsumed(
                    shotProbabilities: sampledShots,
                    pTrack: sampledTrack,
                    doctrine: doctrine
                )
            }

            defendedValues.append(totalDefendedValue)
            expectedShots.append(totalShotsConsumed)
        }

        return MonteCarloSummary(
            samples: samples,
            meanExpectedValue: mean(defendedValues),
            p10ExpectedValue: percentile(defendedValues, percentile: 0.10),
            p90ExpectedValue: percentile(defendedValues, percentile: 0.90),
            meanExpectedShots: mean(expectedShots)
        )
    }

    private static func sampleProbability(baseline: Double, uncertainty: Double) -> Double {
        let sampledValue = baseline + Double.random(in: -uncertainty...uncertainty)
        return min(max(sampledValue, 0.0), 1.0)
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        return values.reduce(0.0, +) / Double(values.count)
    }

    private static func percentile(_ values: [Double], percentile: Double) -> Double {
        guard !values.isEmpty else { return 0.0 }

        let sorted = values.sorted()
        let position = min(max(percentile, 0.0), 1.0) * Double(sorted.count - 1)
        let lowerIndex = Int(position.rounded(.down))
        let upperIndex = Int(position.rounded(.up))

        guard lowerIndex != upperIndex else {
            return sorted[lowerIndex]
        }

        let weight = position - Double(lowerIndex)
        return sorted[lowerIndex] + ((sorted[upperIndex] - sorted[lowerIndex]) * weight)
    }
}
