import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @Bindable var viewModel: WTAViewModel
  @State private var isImporting = false
  @State private var isExporting = false
  @State private var exportDocument = ScenarioDocument(scenario: SampleData.defaultScenario)
  @State private var importErrorMessage: String?
  
  var body: some View {
    ZStack {
      TabView {
        NavigationStack {
          AllocationTabView(viewModel: viewModel)
            .navigationTitle("Allocation")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { mainToolbar }
        }
        .tabItem {
          Label("Allocation", systemImage: "scope")
        }
        
        NavigationStack {
          DailyForecastTabView(viewModel: viewModel)
            .navigationTitle("Daily & forecast")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { mainToolbar }
        }
        .tabItem {
          Label("Daily", systemImage: "chart.line.uptrend.xyaxis")
        }
      }
      .tint(AppTheme.accent)
      
      if viewModel.isComputing {
        Color.black.opacity(0.35)
          .ignoresSafeArea()
        
        ProgressView("Recomputing WTA model…")
          .tint(AppTheme.accent)
          .padding(28)
          .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
              .strokeBorder(AppTheme.cardStroke, lineWidth: 1)
          }
          .shadow(color: .black.opacity(0.35), radius: 24, y: 8)
      }
    }
    .preferredColorScheme(.dark)
    .fileImporter(
      isPresented: $isImporting,
      allowedContentTypes: ScenarioDocument.readableContentTypes
    ) { result in
      handleImport(result)
    }
    .fileExporter(
      isPresented: $isExporting,
      document: exportDocument,
      contentType: .json,
      defaultFilename: "wta-scenario"
    ) { _ in
    }
    .alert("Import failed", isPresented: Binding(
      get: { importErrorMessage != nil },
      set: { if !$0 { importErrorMessage = nil } }
    )) {
      Button("OK", role: .cancel) {
        importErrorMessage = nil
      }
    } message: {
      Text(importErrorMessage ?? "Unknown error")
    }
    .alert("Storage issue", isPresented: Binding(
      get: { viewModel.persistenceErrorMessage != nil },
      set: { if !$0 { viewModel.clearPersistenceError() } }
    )) {
      Button("OK", role: .cancel) {
        viewModel.clearPersistenceError()
      }
    } message: {
      Text(viewModel.persistenceErrorMessage ?? "Unknown error")
    }
  }
  
  @ToolbarContentBuilder
  private var mainToolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .topBarLeading) {
      Button {
        isImporting = true
      } label: {
        Label("Import", systemImage: "square.and.arrow.down")
      }
      
      Button {
        exportDocument = ScenarioDocument(scenario: viewModel.scenario)
        isExporting = true
      } label: {
        Label("Export", systemImage: "square.and.arrow.up")
      }
    }
    
    ToolbarItem(placement: .topBarTrailing) {
      Button {
        viewModel.reset()
      } label: {
        Label("Reset", systemImage: "arrow.counterclockwise")
      }
    }
  }
  
  private func handleImport(_ result: Result<URL, Error>) {
    do {
      let fileURL = try result.get()
      let hasAccess = fileURL.startAccessingSecurityScopedResource()
      defer {
        if hasAccess {
          fileURL.stopAccessingSecurityScopedResource()
        }
      }
      
      let data = try Data(contentsOf: fileURL)
      let scenario = try JSONDecoder().decode(Scenario.self, from: data)
      viewModel.loadScenario(scenario)
    } catch {
      importErrorMessage = error.localizedDescription
    }
  }
}

#Preview {
  @Previewable @State var viewModel = WTAViewModel()
  ContentView(viewModel: viewModel)
}
