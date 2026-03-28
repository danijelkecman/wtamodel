import SwiftUI

struct SectionCard<Content: View>: View {
  let title: String
  var systemImage: String?
  @ViewBuilder var content: () -> Content
  
  init(title: String, systemImage: String? = nil, @ViewBuilder content: @escaping () -> Content) {
    self.title = title
    self.systemImage = systemImage
    self.content = content
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      if let systemImage {
        Label {
          Text(title)
        } icon: {
          Image(systemName: systemImage)
            .symbolRenderingMode(.hierarchical)
        }
        .font(.headline)
        .foregroundStyle(AppTheme.accent)
      } else {
        Text(title)
          .font(.headline)
          .foregroundStyle(.primary)
      }
      
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(AppTheme.cardPadding)
    .background {
      RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay {
          RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
            .strokeBorder(AppTheme.cardStroke, lineWidth: 1)
        }
    }
  }
}

