import SwiftUI

struct ThreatEditorView: View {
  @Binding var threat: Threat
  let maxInterceptors: Int?
  /// With a global budget `G`, this is `G − Σ(other threats’ caps)`
  /// so this threat’s cap keeps Σ caps ≤ `G`. Use `Int.max` when there is no global budget.
  let residualPerThreatCapBudget: Int
  let onRemove: () -> Void
  /// Called when value, shot model, or name changes — usually triggers a solver refresh.
  let onRecalculate: () -> Void
  
  /// Max selectable cap for this threat: never above **Interceptor count**,
  /// and never above what’s left after other threats’ caps (so Σ caps ≤ Interceptor count).
  private var stepperUpperBound: Int {
    guard let globalCap = maxInterceptors else { return Int.max }
    return max(0, min(globalCap, residualPerThreatCapBudget))
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Threat")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Button("Remove", role: .destructive, action: onRemove)
          .font(.caption)
      }
      
      TextField("Name", text: Binding(
        get: { threat.name },
        set: {
          threat.name = $0
          onRecalculate()
        }
      ))
      .textFieldStyle(.roundedBorder)
      
      Toggle(
        "Limit interceptors for this threat",
        isOn: Binding(
          get: { threat.maxAssignedInterceptors != nil },
          set: { isEnabled in
            if isEnabled {
              let hi = stepperUpperBound
              if maxInterceptors != nil {
                if hi == 0 {
                  threat.maxAssignedInterceptors = 0
                } else {
                  let seed = max(threat.maxAssignedInterceptors ?? 1, 1)
                  threat.maxAssignedInterceptors = min(seed, hi)
                }
              } else {
                let defaultLimit = max(threat.maxAssignedInterceptors ?? 1, 1)
                threat.maxAssignedInterceptors = threat.maxAssignedInterceptors ?? defaultLimit
              }
            } else {
              threat.maxAssignedInterceptors = nil
            }
            onRecalculate()
          }
        )
      )
      
      if threat.maxAssignedInterceptors != nil {
        if maxInterceptors != nil {
          Stepper(
            value: Binding(
              get: { min(threat.maxAssignedInterceptors ?? 0, stepperUpperBound) },
              set: {
                threat.maxAssignedInterceptors = min(max($0, 0), stepperUpperBound)
                onRecalculate()
              }
            ),
            in: 0...stepperUpperBound
          ) {
            HStack {
              Text("Threat interceptor limit")
              Spacer()
              Text("\(threat.maxAssignedInterceptors ?? 0)")
                .foregroundStyle(.secondary)
            }
          }
        } else {
          TextField(
            "Threat interceptor limit",
            text: Binding(
              get: {
                guard let maxAssignedInterceptors = threat.maxAssignedInterceptors else { return "" }
                return "\(maxAssignedInterceptors)"
              },
              set: { newValue in
                let filteredValue = newValue.filter(\.isNumber)
                if filteredValue.isEmpty {
                  threat.maxAssignedInterceptors = 0
                } else {
                  threat.maxAssignedInterceptors = max(Int(filteredValue) ?? 0, 0)
                }
                onRecalculate()
              }
            )
          )
          .keyboardType(.numberPad)
        }
        
        Text(limitSummary)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      
      sliderRow(
        title: "Value",
        value: Binding(
          get: { threat.value },
          set: {
            threat.value = $0
            onRecalculate()
          }
        ),
        range: 100...1500,
        step: 50,
        format: { "\(Int($0))" }
      )
      
      sliderRow(
        title: "Base p[1,j]",
        value: Binding(
          get: { threat.baseShotProbability },
          set: {
            threat.baseShotProbability = $0
            onRecalculate()
          }
        ),
        range: 0.05...0.95,
        step: 0.01,
        format: { String(format: "%.2f", $0) }
      )
      
      sliderRow(
        title: "Follow-on decay",
        value: Binding(
          get: { threat.followOnDecay },
          set: {
            threat.followOnDecay = $0
            onRecalculate()
          }
        ),
        range: 0.00...0.20,
        step: 0.005,
        format: { String(format: "%.3f", $0) }
      )
      
      sliderRow(
        title: "P(track)",
        value: Binding(
          get: { threat.pTrack },
          set: {
            threat.pTrack = $0
            onRecalculate()
          }
        ),
        range: 0.50...1.00,
        step: 0.01,
        format: { String(format: "%.2f", $0) }
      )
      
      sliderRow(
        title: "Uncertainty",
        value: Binding(
          get: { threat.uncertainty },
          set: {
            threat.uncertainty = $0
            onRecalculate()
          }
        ),
        range: 0.00...0.20,
        step: 0.01,
        format: { String(format: "\u{00B1}%.2f", $0) }
      )
      
      Text(profilePreview)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 6)
  }
  
  private var profilePreview: String {
    let preview = threat
      .shotProbabilities(maxInterceptors: min(previewInterceptorLimit, 6))
      .map { String(format: "%.2f", $0) }
      .joined(separator: ", ")
    return "p[i,j] preview: \(preview)"
  }
  
  private var previewInterceptorLimit: Int {
    let fallback = max(threat.maxAssignedInterceptors ?? maxInterceptors ?? 6, 1)
    guard let globalCap = maxInterceptors else { return fallback }
    return max(min(fallback, globalCap), 1)
  }
  
  private var limitSummary: String {
    if let globalCap = maxInterceptors {
      if globalCap == 0 {
        return "Interceptor count is 0 — no interceptors can be assigned."
      }
      return "Interceptor count is \(globalCap): this threat cannot exceed \(globalCap) interceptors, and right now you can set at most \(stepperUpperBound) here so that every threat’s limit stays within \(globalCap) in total. Tap Recalculate options to refresh allocations after changing this limit."
    }
    
    return "Interceptor count is empty (limitless interceptor supply). This optional ceiling is not capped by a global total. Tap Recalculate options to refresh allocations after changing this limit."
  }
  
  @ViewBuilder
  private func sliderRow(
    title: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    step: Double,
    format: @escaping (Double) -> String
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(title)
        Spacer()
        Text(format(value.wrappedValue))
          .foregroundStyle(.secondary)
      }
      
      Slider(value: value, in: range, step: step)
    }
  }
}
