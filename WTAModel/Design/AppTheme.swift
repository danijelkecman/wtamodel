import SwiftUI

enum AppTheme {
  static let cornerRadius: CGFloat = 16
  static let cardPadding: CGFloat = 16
  static let sectionSpacing: CGFloat = 18
  static let screenHorizontalPadding: CGFloat = 20
  
  static let accent = Color(red: 0.35, green: 0.85, blue: 0.82)
  static let accentSecondary = Color(red: 0.45, green: 0.55, blue: 0.95)
  
  static var screenBackground: LinearGradient {
    LinearGradient(
      colors: [
        Color(red: 0.06, green: 0.08, blue: 0.14),
        Color(red: 0.04, green: 0.06, blue: 0.11),
        Color(red: 0.03, green: 0.05, blue: 0.09)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
  
  static let cardStroke = Color.white.opacity(0.12)
}

struct WtaScrollScreen<Content: View>: View {
  @ViewBuilder var content: () -> Content
  
  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: AppTheme.sectionSpacing, content: content)
        .padding(.horizontal, AppTheme.screenHorizontalPadding)
        .padding(.vertical, 12)
    }
    .scrollIndicators(.hidden)
    .background(AppTheme.screenBackground.ignoresSafeArea())
  }
}

struct PrimaryWtaButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.black.opacity(0.92))
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(AppTheme.accent.opacity(configuration.isPressed ? 0.75 : 1))
      )
  }
}

struct SecondaryWtaButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.subheadline.weight(.medium))
      .foregroundStyle(AppTheme.accent)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(AppTheme.accent.opacity(0.55), lineWidth: 1)
          .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(Color.white.opacity(configuration.isPressed ? 0.06 : 0.03))
          )
      )
  }
}

