import Foundation

enum DailyObservationsPersistence {
    private nonisolated static let fileName = "saved_daily_observations.json"

    private nonisolated static func resolvedFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("WTAModel", isDirectory: true)
        return folder.appendingPathComponent(fileName, isDirectory: false)
    }

    nonisolated static func load() -> [DailyObservation] {
        let url = resolvedFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([DailyObservation].self, from: data)
            return decoded.sorted { $0.date < $1.date }
        } catch {
            return []
        }
    }

    nonisolated static func save(_ observations: [DailyObservation]) {
        let url = resolvedFileURL()
        let folder = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(observations.sorted { $0.date < $1.date })
            try data.write(to: url, options: .atomic)
        } catch {
            // Best-effort persistence; UI still holds in-memory state.
        }
    }
}
