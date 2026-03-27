import SwiftUI

@main
struct WTAModelApp: App {
    @State private var viewModel = WTAViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .tint(AppTheme.accent)
        }
    }
}
