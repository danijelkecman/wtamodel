import SwiftUI
import Charts

struct MarginalGainChartView: View {
  let threats: [Threat]
  /// `nil` = no global interceptor budget (chart extends to meaningful marginal-gain depth).
  let globalInterceptorBudget: Int?
  
  private var chartAxisMax: Int {
    DefenseMath.chartInterceptorDisplayMax(threats: threats, globalInterceptorBudget: globalInterceptorBudget)
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Marginal gain and diminishing returns")
        .font(.headline)
        .foregroundStyle(AppTheme.accent)
      
      Chart(chartPoints) { point in
        LineMark(
          x: .value("Interceptor", point.interceptorNumber),
          y: .value("Gain", point.gain)
        )
        .foregroundStyle(by: .value("Threat", point.threatName))
        
        PointMark(
          x: .value("Interceptor", point.interceptorNumber),
          y: .value("Gain", point.gain)
        )
        .foregroundStyle(by: .value("Threat", point.threatName))
      }
      .frame(height: 220)
      
      Text("Each series shows the defended-value gain from adding the next interceptor to a single threat.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
  
  private var chartPoints: [MarginalGainPoint] {
    guard chartAxisMax > 0 else { return [] }
    
    return threats.flatMap { threat in
      (0..<chartAxisMax).map { index in
        MarginalGainPoint(
          threatName: threat.name,
          interceptorNumber: index + 1,
          gain: DefenseMath.marginalGain(threat: threat, currentInterceptors: index)
        )
      }
    }
  }
}

private struct MarginalGainPoint: Identifiable {
  let threatName: String
  let interceptorNumber: Int
  let gain: Double
  
  var id: String {
    "\(threatName)-\(interceptorNumber)"
  }
}

