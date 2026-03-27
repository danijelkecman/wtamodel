import Foundation

enum DailyDefenseEstimator {
    enum Method {
        case exact
        case greedy
    }

    static func estimate(
        threats: [Threat],
        totalIncoming: Int,
        perThreatIncoming: [Int],
        totalInterceptors: Int?,
        doctrine: EngagementDoctrine
    ) -> DailyDefenseEstimate? {
        estimate(
            threats: threats,
            totalIncoming: totalIncoming,
            perThreatIncoming: perThreatIncoming,
            totalInterceptors: totalInterceptors,
            doctrine: doctrine,
            method: .greedy
        )
    }

    static func estimate(
        threats: [Threat],
        totalIncoming: Int,
        perThreatIncoming: [Int],
        totalInterceptors: Int?,
        doctrine: EngagementDoctrine,
        method: Method
    ) -> DailyDefenseEstimate? {
        let normalizedIncoming = normalizedIncomingDistribution(
            threats: threats,
            totalIncoming: totalIncoming,
            perThreatIncoming: perThreatIncoming
        )
        let incomingCount = normalizedIncoming.reduce(0, +)

        guard incomingCount > 0 else { return nil }

        let warheads = expandedWarheads(threats: threats, incomingDistribution: normalizedIncoming)
        let allocationResult: AllocationResult?

        switch method {
        case .exact:
            guard ExactAllocator.shouldRunExactly(
                threatCount: warheads.count,
                totalInterceptors: totalInterceptors
            ) else {
                return nil
            }

            allocationResult = ExactAllocator.solve(
                threats: warheads,
                totalInterceptors: totalInterceptors,
                doctrine: doctrine,
                monteCarloSamples: 0
            )
        case .greedy:
            allocationResult = GreedyAllocator.solve(
                threats: warheads,
                totalInterceptors: totalInterceptors,
                doctrine: doctrine,
                monteCarloSamples: 0
            )
        }

        guard let allocationResult else { return nil }

        let expectedSuccessfulIntercepts = allocationResult.totalExpectedValue
        let expectedLeakThrough = max(Double(incomingCount) - expectedSuccessfulIntercepts, 0.0)

        return DailyDefenseEstimate(
            incomingCount: incomingCount,
            successRate: expectedSuccessfulIntercepts / Double(incomingCount),
            expectedSuccessfulIntercepts: expectedSuccessfulIntercepts,
            expectedLeakThrough: expectedLeakThrough,
            expectedShotsConsumed: allocationResult.totalExpectedShots
        )
    }

    private static func normalizedIncomingDistribution(
        threats: [Threat],
        totalIncoming: Int,
        perThreatIncoming: [Int]
    ) -> [Int] {
        guard !threats.isEmpty else { return [] }

        let normalizedTotalIncoming = max(totalIncoming, 0)
        var distribution = Array(perThreatIncoming.prefix(threats.count)).map { max($0, 0) }

        if distribution.count < threats.count {
            distribution.append(contentsOf: Array(repeating: 0, count: threats.count - distribution.count))
        }

        let assignedIncoming = distribution.reduce(0, +)
        guard normalizedTotalIncoming > assignedIncoming else {
            return distribution
        }

        let remainingIncoming = normalizedTotalIncoming - assignedIncoming
        let baseWeights = distribution.contains(where: { $0 > 0 })
            ? distribution.map(Double.init)
            : Array(repeating: 1.0, count: threats.count)

        let weightTotal = baseWeights.reduce(0.0, +)
        guard weightTotal > 0 else { return distribution }

        let scaledWeights = baseWeights.map { ($0 / weightTotal) * Double(remainingIncoming) }
        let floorAllocations = scaledWeights.map { Int($0.rounded(.down)) }
        let remainderCount = remainingIncoming - floorAllocations.reduce(0, +)

        for index in distribution.indices {
            distribution[index] += floorAllocations[index]
        }

        let prioritizedRemainders = scaledWeights.enumerated()
            .map { index, scaledWeight in (index: index, remainder: scaledWeight - Double(floorAllocations[index])) }
            .sorted { lhs, rhs in
                if lhs.remainder == rhs.remainder {
                    return lhs.index < rhs.index
                }
                return lhs.remainder > rhs.remainder
            }

        for prioritized in prioritizedRemainders.prefix(remainderCount) {
            distribution[prioritized.index] += 1
        }

        return distribution
    }

    private static func expandedWarheads(
        threats: [Threat],
        incomingDistribution: [Int]
    ) -> [Threat] {
        zip(threats, incomingDistribution).flatMap { threat, incomingCount in
            (0..<incomingCount).map { _ in
                Threat(
                    name: threat.name,
                    value: 1.0,
                    baseShotProbability: threat.baseShotProbability,
                    followOnDecay: threat.followOnDecay,
                    pTrack: threat.pTrack,
                    uncertainty: threat.uncertainty
                )
            }
        }
    }
}
