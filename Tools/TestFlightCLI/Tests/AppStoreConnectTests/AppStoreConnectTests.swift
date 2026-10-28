import CryptoKit
import Foundation
import Testing
@testable import AppStoreConnect

struct AuthTokenTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func teamKeyTokenMatchesApplesShapeAndVerifies() throws {
        let key = P256.Signing.PrivateKey()
        let token = try AuthToken.make(keyID: "2X9R4HXF34", issuerID: "57246542-96fe-1a63-e053-0824d011072a", key: key, now: now)
        let parts = token.split(separator: ".").map(String.init)
        #expect(parts.count == 3)

        let header = try JSONDecoder().decode(AuthToken.Header.self, from: base64URLDecoded(parts[0]))
        #expect(header.alg == "ES256")
        #expect(header.kid == "2X9R4HXF34")
        #expect(header.typ == "JWT")

        let payload = try base64URLDecoded(parts[1])
        let keys = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any]).keys
        #expect(Set(keys) == ["iss", "iat", "exp", "aud"])
        let claims = try JSONDecoder().decode(AuthToken.Claims.self, from: payload)
        #expect(claims.iss == "57246542-96fe-1a63-e053-0824d011072a")
        #expect(claims.aud == "appstoreconnect-v1")
        #expect(claims.iat == 1_800_000_000)
        #expect(claims.exp - claims.iat == 900)

        let signature = try P256.Signing.ECDSASignature(rawRepresentation: base64URLDecoded(parts[2]))
        #expect(key.publicKey.isValidSignature(signature, for: Data("\(parts[0]).\(parts[1])".utf8)))
    }

    @Test func individualKeySignsAsTheUser() throws {
        let token = try AuthToken.make(keyID: "2X9R4HXF34", issuerID: nil, key: P256.Signing.PrivateKey(), now: now)
        let payload = try base64URLDecoded(String(token.split(separator: ".")[1]))
        let keys = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any]).keys
        #expect(Set(keys) == ["sub", "iat", "exp", "aud"])
        #expect(try JSONDecoder().decode(AuthToken.Claims.self, from: payload).sub == "user")
    }

    /// Apple's .p8 files are PKCS#8 PEM, the same shape CryptoKit writes.
    @Test func readsAPKCS8KeyFile() throws {
        let key = P256.Signing.PrivateKey()
        let directory = try temporaryDirectory()
        let file = directory.appending(path: "AuthKey_TEST123456.p8")
        try key.pemRepresentation.write(to: file, atomically: true, encoding: .utf8)
        #expect(key.pemRepresentation.hasPrefix("-----BEGIN PRIVATE KEY-----"))
        let token = try AuthToken.make(for: Credentials(issuerID: "issuer", keyID: "TEST123456", privateKeyURL: file), now: now)
        let parts = token.split(separator: ".").map(String.init)
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: base64URLDecoded(parts[2]))
        #expect(key.publicKey.isValidSignature(signature, for: Data("\(parts[0]).\(parts[1])".utf8)))
    }

    @Test func missingKeyFileSaysWhereItShouldBe() throws {
        let credentials = Credentials(issuerID: "issuer", keyID: "MISSING", privateKeyURL: URL(filePath: "/nonexistent/AuthKey_MISSING.p8"))
        #expect {
            _ = try AuthToken.make(for: credentials)
        } throws: { error in
            (error as? ASCError)?.errorDescription?.contains("/nonexistent/AuthKey_MISSING.p8") == true
        }
    }
}

struct CredentialsTests {
    @Test func savesAndLoadsTheConfigFile() throws {
        let directory = try temporaryDirectory()
        let keyURL = Credentials.defaultKeyURL(keyID: "ABCDE12345", in: directory)
        try Credentials(issuerID: "issuer-1", keyID: "ABCDE12345", privateKeyURL: keyURL).save(in: directory)

        let saved = try String(contentsOf: Credentials.configURL(in: directory), encoding: .utf8)
        #expect(!saved.contains("privateKeyPath"), "the conventional key location isn't written out")
        let permissions = try FileManager.default.attributesOfItem(atPath: Credentials.configURL(in: directory).path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)

        let loaded = try Credentials.load(environment: [:], directory: directory)
        #expect(loaded.keyID == "ABCDE12345")
        #expect(loaded.issuerID == "issuer-1")
        #expect(loaded.privateKeyURL.lastPathComponent == "AuthKey_ABCDE12345.p8")
    }

    @Test func environmentOverridesTheConfigFile() throws {
        let directory = try temporaryDirectory()
        try Credentials(issuerID: "issuer-1", keyID: "ABCDE12345", privateKeyURL: Credentials.defaultKeyURL(keyID: "ABCDE12345", in: directory)).save(in: directory)
        let loaded = try Credentials.load(environment: ["ASC_KEY_ID": "ZZZZZ99999", "ASC_PRIVATE_KEY_PATH": "/keys/custom.p8"], directory: directory)
        #expect(loaded.keyID == "ZZZZZ99999")
        #expect(loaded.issuerID == "issuer-1")
        #expect(loaded.privateKeyURL.path == "/keys/custom.p8")
    }

    @Test func missingConfigurationExplainsSetup() throws {
        let directory = try temporaryDirectory()
        #expect {
            _ = try Credentials.load(environment: [:], directory: directory)
        } throws: { error in
            (error as? ASCError)?.errorDescription?.contains("Tools/testflight setup") == true
        }
    }
}

struct DecodingTests {
    @Test func readsScreenshotFeedbackWithBuildAndTester() throws {
        let page = try JSONDecoder().decode(ListResponse<FeedbackAttributes>.self, from: Data(Fixtures.screenshotFeedback.utf8))
        let items = Client.items(.screenshot, in: page)
        let item = try #require(items.first)
        #expect(items.count == 1)
        #expect(item.id == "AbCdEf123456")
        #expect(item.buildNumber == "6")
        #expect(item.tester == "Ash Ketchum")
        #expect(item.comment == "Crown scrolling skips the stats")
        #expect(item.deviceSummary == "iPhone18,2 · iOS 27.1")
        #expect(item.createdDate != nil, "fractional seconds and offsets parse")
        #expect(item.attributes.screenshots?.first?.url?.absoluteString == "https://example.com/s1.png")
        #expect(page.meta?.paging?.total == 3)
        #expect(page.links?.next != nil)

        let markdown = item.markdown(files: ["screenshot-1.png"])
        #expect(markdown.contains("> Crown scrolling skips the stats"))
        #expect(markdown.contains("- Build: build 6 (iOS)"))
        #expect(markdown.contains("- App uptime: 3 min 12 s"))
    }

    @Test func readsAppStoreConnectErrors() {
        let body = Data(#"{"errors":[{"status":"401","code":"NOT_AUTHORIZED","title":"Authentication credentials are missing or invalid.","detail":"Provide a properly configured and signed bearer token."}]}"#.utf8)
        #expect(ErrorDocument.messages(in: body) == ["Authentication credentials are missing or invalid. Provide a properly configured and signed bearer token."])
        #expect(ErrorDocument.messages(in: Data("not json".utf8)).isEmpty)
    }
}

struct ArchiveTests {
    @Test func savesReportsAndTracksHandledOnes() throws {
        let archive = FeedbackArchive(root: try temporaryDirectory().appending(path: "Ethan.Neodex"))
        let page = try JSONDecoder().decode(ListResponse<FeedbackAttributes>.self, from: Data(Fixtures.screenshotFeedback.utf8))
        let item = try #require(Client.items(.screenshot, in: page).first)

        let folder = try archive.prepareFolder(for: item)
        #expect(folder.lastPathComponent.hasSuffix("-screenshot-AbCdEf12"))
        try Data([0x89]).write(to: folder.appending(path: "screenshot-1.png"))
        #expect(archive.existingFile(named: "screenshot-1", in: folder)?.lastPathComponent == "screenshot-1.png")
        #expect(archive.existingFile(named: "screenshot-2", in: folder) == nil)
        try archive.writeDetails(for: item, files: ["screenshot-1.png"], in: folder)

        #expect(try archive.resolve("AbCd") == "AbCdEf123456")
        #expect(throws: ASCError.self) { try archive.resolve("zzz") }

        var state = archive.loadState()
        #expect(state.handled.isEmpty)
        state.handled[item.id] = .init(date: .now, note: "fixed in abc1234")
        try archive.save(state)
        #expect(archive.loadState().handled[item.id]?.note == "fixed in abc1234")
    }
}

enum Fixtures {
    /// The shape of `GET /v1/apps/{id}/betaFeedbackScreenshotSubmissions?include=build,tester`.
    static let screenshotFeedback = """
    {
      "data": [{
        "type": "betaFeedbackScreenshotSubmissions",
        "id": "AbCdEf123456",
        "attributes": {
          "createdDate": "2026-10-27T21:14:05.123-04:00",
          "comment": "Crown scrolling skips the stats",
          "email": "tester@example.com",
          "deviceModel": "iPhone18,2",
          "osVersion": "27.1",
          "locale": "en-US",
          "timeZone": "America/New_York",
          "architecture": "arm64e",
          "connectionType": "WIFI",
          "appUptimeInMilliseconds": 192000,
          "diskBytesAvailable": 100000000000,
          "diskBytesTotal": 256000000000,
          "batteryPercentage": 82,
          "screenWidthInPoints": 440,
          "screenHeightInPoints": 956,
          "appPlatform": "IOS",
          "devicePlatform": "IOS",
          "deviceFamily": "IPHONE",
          "buildBundleId": "Ethan.Neodex",
          "screenshots": [{"url": "https://example.com/s1.png", "width": 1320, "height": 2868, "expirationDate": "2026-10-28T21:14:05Z"}]
        },
        "relationships": {
          "build": {"links": {"self": "https://api.appstoreconnect.apple.com/v1/x"}, "data": {"type": "builds", "id": "build-6"}},
          "tester": {"data": {"type": "betaTesters", "id": "tester-1"}}
        }
      }],
      "included": [
        {"type": "builds", "id": "build-6", "attributes": {"version": "6"}},
        {"type": "betaTesters", "id": "tester-1", "attributes": {"firstName": "Ash", "lastName": "Ketchum"}}
      ],
      "links": {
        "self": "https://api.appstoreconnect.apple.com/v1/apps/1/betaFeedbackScreenshotSubmissions",
        "next": "https://api.appstoreconnect.apple.com/v1/apps/1/betaFeedbackScreenshotSubmissions?cursor=Mg"
      },
      "meta": {"paging": {"total": 3, "limit": 1}}
    }
    """
}

func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "testflight-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func base64URLDecoded(_ string: String) throws -> Data {
    var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while base64.count % 4 != 0 { base64 += "=" }
    return try #require(Data(base64Encoded: base64))
}
