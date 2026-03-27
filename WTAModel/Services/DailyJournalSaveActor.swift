import Foundation

/// Serializes writes to the on-disk daily journal so rapid saves don’t interleave.
actor DailyJournalSaveActor {
    static let shared = DailyJournalSaveActor()

    func save(_ observations: [DailyObservation]) {
        DailyObservationsPersistence.save(observations)
    }
}
