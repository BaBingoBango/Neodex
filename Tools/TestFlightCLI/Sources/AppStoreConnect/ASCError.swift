import Foundation

/// Everything that can go wrong, worded for the person who has to fix it.
public enum ASCError: LocalizedError, Sendable {
    case notConfigured
    case configUnreadable(URL)
    case keyMissing(URL)
    case keyInvalid(URL)
    case http(status: Int, messages: [String])
    case appNotFound(String)
    case unexpected(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return """
            App Store Connect isn't set up yet. In App Store Connect, open Users and Access › Integrations › \
            App Store Connect API, create a team key with the Developer role, download its AuthKey_<KEY ID>.p8 \
            file, then run:
              Tools/testflight setup --issuer-id <ISSUER ID> --key-id <KEY ID>
            """
        case .configUnreadable(let url):
            return "Couldn't read \(url.path). Run Tools/testflight setup again to rewrite it."
        case .keyMissing(let url):
            return "No private key at \(url.path). Apple offers the .p8 file only once, when the key is created; "
                + "save it there, or rerun setup with --key-path pointing at it."
        case .keyInvalid(let url):
            return "\(url.lastPathComponent) isn't a valid App Store Connect private key."
        case .http(let status, let messages):
            var text = "App Store Connect answered \(status)" + (messages.isEmpty ? "." : ": " + messages.joined(separator: " "))
            switch status {
            case 401: text += "\nCheck the key ID and issuer ID, and that the key hasn't been revoked."
            case 403: text += "\nThe key's role can't do this. TestFlight feedback needs the Developer, App Manager or Admin role."
            case 429: text += "\nApp Store Connect is rate limiting requests. Wait a minute and try again."
            default: break
            }
            return text
        case .appNotFound(let bundleID):
            return "No app with the bundle ID \(bundleID) is visible to this key."
        case .unexpected(let message):
            return message
        }
    }
}
