import Foundation
import NeodexKit

/// What the iPhone hands the watch over WatchConnectivity: the saved teams as plain values. `TeamMember`
/// is already a Codable value, so the wrist sees exactly what the Teambuilder saved.
struct WatchTeamSnapshot: Codable {
    struct Team: Codable, Identifiable {
        var id: UUID
        var name: String
        var format: String?
        var updatedAt: Date
        var members: [TeamMember]
    }

    var generatedAt: Date
    var teams: [Team]

    /// The application-context key the snapshot travels under.
    nonisolated static let contextKey = "teams"
    /// Enough teams to be useful, few enough to stay well inside WatchConnectivity's payload limits.
    nonisolated static let maximumTeams = 20

    func encoded() throws -> Data { try JSONEncoder().encode(self) }

    static func decode(_ data: Data) throws -> WatchTeamSnapshot { try JSONDecoder().decode(WatchTeamSnapshot.self, from: data) }
}

/// The question-and-answer protocol between the watch and Dexbot on the iPhone. A question travels
/// as an interactive message when the iPhone is reachable, and as a queued transfer otherwise; the
/// answer comes back the same way, matched by id.
nonisolated enum WatchDexbotMessage {
    static let kindKey = "kind"
    static let askKind = "ask"
    static let answerKind = "answer"
    static let idKey = "id"
    static let questionKey = "question"
    static let answerKey = "answer"
    static let errorKey = "error"
}
