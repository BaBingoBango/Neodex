import Foundation

/// A trainer card as Wallet's `pass.json`: a generic pass with the trainer's name up top, the picture as its
/// thumbnail and the Pokédex counts below.
nonisolated struct TrainerPass: Encodable, Sendable {
    /// Must match the certificate that signs the pass (see `Server/README.md`).
    static let passTypeIdentifier = "pass.Ethan.Neodex.trainer"
    static let teamIdentifier = "GUDZ7ALN9J"

    let formatVersion = 1
    let passTypeIdentifier = TrainerPass.passTypeIdentifier
    let teamIdentifier = TrainerPass.teamIdentifier
    let organizationName = "Neodex"
    let description = "Neodex Trainer Card"
    let logoText = "Trainer Card"
    /// Random, and the same for every version of one trainer's pass, since Wallet matches updates by it.
    var serialNumber: String
    var backgroundColor: String
    var foregroundColor = "rgb(255, 255, 255)"
    var labelColor = "rgb(255, 255, 255)"
    var generic: Fields

    nonisolated struct Fields: Encodable, Sendable {
        var primaryFields: [Field]
        var secondaryFields: [Field]
        var auxiliaryFields: [Field]
        var backFields: [Field]
    }

    nonisolated struct Field: Encodable, Sendable {
        var key: String
        var label: String?
        var value: Value

        nonisolated enum Value: Encodable, Sendable {
            case text(String)
            case number(Int)

            func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .text(let text): try container.encode(text)
                case .number(let number): try container.encode(number)
                }
            }
        }
    }

    init(serialNumber: String, name: String, trainerID: String, seen: Int, caught: Int, team: [String],
         background: (red: Int, green: Int, blue: Int)) {
        self.serialNumber = serialNumber
        backgroundColor = "rgb(\(background.red), \(background.green), \(background.blue))"
        var back = [Field(key: "issuer", label: "Issued by", value: .text("Neodex · neodexapp.com"))]
        if !team.isEmpty {
            back.insert(Field(key: "team", label: "Team", value: .text(team.joined(separator: " · "))), at: 0)
        }
        generic = Fields(
            primaryFields: [Field(key: "name", label: "TRAINER", value: .text(name))],
            secondaryFields: [Field(key: "id", label: "ID NO.", value: .text(trainerID))],
            auxiliaryFields: [
                Field(key: "seen", label: "SEEN", value: .number(seen)),
                Field(key: "caught", label: "CAUGHT", value: .number(caught)),
            ],
            backFields: back)
    }

    /// The pass.json bytes, with stable key order.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}
