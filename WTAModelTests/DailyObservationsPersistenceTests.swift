import XCTest
@testable import WTAModel

final class DailyObservationsPersistenceTests: XCTestCase {
  func testLoadReturnsEmptyArrayWhenFileDoesNotExist() throws {
    let url = temporaryFileURL()
    
    XCTAssertEqual(try DailyObservationsPersistence.load(from: url), [])
  }
  
  func testSaveAndLoadRoundTripUsesChronologicalOrder() throws {
    let url = temporaryFileURL()
    let laterDate = Date(timeIntervalSince1970: 2_000)
    let earlierDate = Date(timeIntervalSince1970: 1_000)
    
    let observations = [
      DailyObservation(
        date: laterDate,
        totalIncoming: 4,
        totalHits: 1,
        perThreatIncoming: [DailyThreatObservation(threatID: UUID(), threatName: "Later", incomingCount: 4)]
      ),
      DailyObservation(
        date: earlierDate,
        totalIncoming: 2,
        totalHits: 0,
        perThreatIncoming: [DailyThreatObservation(threatID: UUID(), threatName: "Earlier", incomingCount: 2)]
      )
    ]
    
    try DailyObservationsPersistence.save(observations, to: url)
    let loaded = try DailyObservationsPersistence.load(from: url)
    
    XCTAssertEqual(loaded.map(\.date), [earlierDate, laterDate])
    XCTAssertEqual(loaded.map(\.totalIncoming), [2, 4])
  }
  
  private func temporaryFileURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("saved_daily_observations.json", isDirectory: false)
  }
}
