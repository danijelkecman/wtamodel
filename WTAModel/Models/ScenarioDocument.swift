import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ScenarioDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json] }
  
  var scenario: Scenario
  
  init(scenario: Scenario) {
    self.scenario = scenario
  }
  
  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    scenario = try JSONDecoder().decode(Scenario.self, from: data)
  }
  
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(scenario)
    return FileWrapper(regularFileWithContents: data)
  }
}

