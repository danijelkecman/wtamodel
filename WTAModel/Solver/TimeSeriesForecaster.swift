import Foundation

enum TimeSeriesForecaster {
    static func forecasts(observations: [DailyObservation]) -> [ThreatForecast] {
        let threatNames = Array(
            Set(
                observations.flatMap { observation in
                    observation.perThreatIncoming.map(\.threatName)
                }
            )
        ).sorted()

        return threatNames.compactMap { threatName in
            forecast(threatName: threatName, observations: observations)
        }
        .sorted { $0.predictedIncomingCount > $1.predictedIncomingCount }
    }

    private static func forecast(threatName: String, observations: [DailyObservation]) -> ThreatForecast? {
        let sortedObservations = observations.sorted { $0.date < $1.date }
        let series = sortedObservations.map { observation in
            Double(observation.incomingCount(forThreatNamed: threatName))
        }

        guard !series.isEmpty else { return nil }

        let recentValues = Array(series.suffix(min(3, series.count)))
        let recentAverage = recentValues.reduce(0.0, +) / Double(recentValues.count)

        guard series.count > 1 else {
            return ThreatForecast(
                threatName: threatName,
                predictedIncomingCount: max(recentAverage, 0.0),
                recentAverage: recentAverage,
                trendPerDay: 0.0,
                sampleCount: 1
            )
        }

        let xValues = timeOffsets(for: sortedObservations)
        let trend = linearTrend(xValues: xValues, yValues: series)
        let nextX = (xValues.last ?? 0.0) + 1.0
        let regressionPrediction = (trend.intercept + (trend.slope * nextX))
        let blendedPrediction = max((regressionPrediction * 0.6) + (recentAverage * 0.4), 0.0)

        return ThreatForecast(
            threatName: threatName,
            predictedIncomingCount: blendedPrediction,
            recentAverage: recentAverage,
            trendPerDay: trend.slope,
            sampleCount: series.count
        )
    }

    private static func timeOffsets(for observations: [DailyObservation]) -> [Double] {
        guard let firstDate = observations.first?.date else { return [] }
        let calendar = Calendar.current

        return observations.map { observation in
            Double(calendar.dateComponents([.day], from: firstDate, to: observation.date).day ?? 0)
        }
    }

    private static func linearTrend(xValues: [Double], yValues: [Double]) -> (slope: Double, intercept: Double) {
        let count = Double(xValues.count)
        let xMean = xValues.reduce(0.0, +) / count
        let yMean = yValues.reduce(0.0, +) / count

        let numerator = zip(xValues, yValues).reduce(0.0) { partialResult, pair in
            let centeredX = pair.0 - xMean
            let centeredY = pair.1 - yMean
            return partialResult + (centeredX * centeredY)
        }

        let denominator = xValues.reduce(0.0) { partialResult, x in
            let centeredX = x - xMean
            return partialResult + (centeredX * centeredX)
        }

        guard denominator > 0 else {
            return (slope: 0.0, intercept: yMean)
        }

        let slope = numerator / denominator
        let intercept = yMean - (slope * xMean)
        return (slope: slope, intercept: intercept)
    }
}
