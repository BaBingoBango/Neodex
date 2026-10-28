import CryptoKit
import Foundation

/// The signed JSON Web Token App Store Connect expects on every request: ES256 with the API key, an
/// audience of `appstoreconnect-v1`, and a lifetime under Apple's twenty-minute ceiling.
public enum AuthToken {
    public static let audience = "appstoreconnect-v1"
    public static let lifetime: TimeInterval = 15 * 60

    public static func make(for credentials: Credentials, now: Date = .now) throws -> String {
        let url = credentials.privateKeyURL
        guard FileManager.default.fileExists(atPath: url.path) else { throw ASCError.keyMissing(url) }
        let key: P256.Signing.PrivateKey
        do {
            key = try P256.Signing.PrivateKey(pemRepresentation: String(contentsOf: url, encoding: .utf8))
        } catch {
            throw ASCError.keyInvalid(url)
        }
        return try make(keyID: credentials.keyID, issuerID: credentials.issuerID, key: key, now: now)
    }

    static func make(keyID: String, issuerID: String?, key: P256.Signing.PrivateKey, now: Date) throws -> String {
        let issued = Int(now.timeIntervalSince1970)
        let header = Header(alg: "ES256", kid: keyID, typ: "JWT")
        // Team keys name their issuer; individual keys sign as the user.
        let claims = Claims(iss: issuerID, sub: issuerID == nil ? "user" : nil,
                            iat: issued, exp: issued + Int(lifetime), aud: audience)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let signingInput = try base64URL(encoder.encode(header)) + "." + base64URL(encoder.encode(claims))
        let signature = try key.signature(for: Data(signingInput.utf8))
        return signingInput + "." + base64URL(signature.rawRepresentation)
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    struct Header: Codable {
        let alg: String
        let kid: String
        let typ: String
    }

    struct Claims: Codable {
        let iss: String?
        let sub: String?
        let iat: Int
        let exp: Int
        let aud: String
    }
}
