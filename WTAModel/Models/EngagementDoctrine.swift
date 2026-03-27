import Foundation

enum EngagementDoctrine: String, CaseIterable, Codable, Identifiable, Sendable {
    case salvo
    case shootLookShoot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .salvo:
            return "Salvo"
        case .shootLookShoot:
            return "Shoot-Look-Shoot"
        }
    }

    var summary: String {
        switch self {
        case .salvo:
            return "All assigned interceptors are committed after tracking succeeds."
        case .shootLookShoot:
            return "Follow-on shots are only fired after earlier shots fail."
        }
    }
}
