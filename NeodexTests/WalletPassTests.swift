import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Neodex

/// The Trainer Card's Wallet pass, built on the device: its zip, manifest, image nonces and pass.json.
@Suite("Wallet pass package")
struct WalletPassTests {
    @Test("CRC-32 matches the standard check value")
    func crc() {
        #expect(CRC32.checksum(Data("123456789".utf8)) == 0xCBF4_3926)
        #expect(CRC32.checksum(Data()) == 0)
    }

    @Test("The zip holds every file at its top level, intact")
    func zipRoundTrip() throws {
        var zip = ZipArchive()
        let files = [("pass.json", Data("{\"formatVersion\":1}".utf8)), ("icon@2x.png", Data((0 ..< 300).map { UInt8($0 % 256) }))]
        for (name, contents) in files { zip.add(name, contents) }
        let entries = try ZipReader.entries(of: zip.data)
        #expect(entries.map(\.name) == files.map(\.0))
        #expect(entries.map(\.contents) == files.map(\.1))
    }

    @Test("The manifest lists each file's SHA-1, and the archive adds the manifest and signature")
    func manifest() throws {
        let package = try WalletPassPackage(files: ["pass.json": Data("abc".utf8), "icon.png": Data()])
        let manifest = try #require(try JSONSerialization.jsonObject(with: package.manifest) as? [String: String])
        #expect(manifest == ["pass.json": "a9993e364706816aba3e25717850c26c9cd0d89d", "icon.png": "da39a3ee5e6b4b0d3255bfef95601890afd80709"])

        let signature = Data([0x30, 0x82])
        let entries = try ZipReader.entries(of: package.archive(signature: signature))
        #expect(entries.map(\.name) == ["icon.png", "pass.json", "manifest.json", "signature"])
        #expect(entries.first { $0.name == "manifest.json" }?.contents == package.manifest)
        #expect(entries.first { $0.name == "signature" }?.contents == signature)
    }

    @Test("A nonce changes a PNG's hash but not the picture")
    func pngNonce() throws {
        let png = try Self.onePixelPNG()
        let first = try #require(PNGNonce.adding(to: png, nonce: "one"))
        let second = try #require(PNGNonce.adding(to: png, nonce: "two"))
        #expect(first != second && first != png)
        for marked in [first, second] {
            let source = try #require(CGImageSourceCreateWithData(marked as CFData, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            #expect(image.width == 1 && image.height == 1)
        }
        #expect(PNGNonce.adding(to: Data("not a png".utf8)) == nil)
    }

    @Test("pass.json carries the pass type and team the certificate is for, and the card's fields")
    func passJSON() throws {
        let pass = TrainerPass(serialNumber: "serial", name: "Ethan", trainerID: "04821", seen: 312, caught: 7,
                               team: ["Garchomp", "Kingambit"], background: (red: 40, green: 60, blue: 120))
        let json = try #require(try JSONSerialization.jsonObject(with: pass.encoded()) as? [String: Any])
        #expect(json["formatVersion"] as? Int == 1)
        #expect(json["passTypeIdentifier"] as? String == "pass.Ethan.Neodex.trainer")
        #expect(json["teamIdentifier"] as? String == "GUDZ7ALN9J")
        #expect(json["backgroundColor"] as? String == "rgb(40, 60, 120)")
        let generic = try #require(json["generic"] as? [String: [[String: Any]]])
        #expect(generic["primaryFields"]?.first?["value"] as? String == "Ethan")
        #expect(generic["auxiliaryFields"]?.first?["value"] as? Int == 312)
        #expect(generic["backFields"]?.first?["value"] as? String == "Garchomp · Kingambit")

        let teamless = TrainerPass(serialNumber: "s", name: "N", trainerID: "1", seen: 0, caught: 0, team: [],
                                   background: (red: 0, green: 0, blue: 0))
        let back = try #require((try JSONSerialization.jsonObject(with: teamless.encoded()) as? [String: Any])?["generic"] as? [String: [[String: Any]]])
        #expect(back["backFields"]?.map { $0["key"] as? String } == ["issuer"])
    }

    private static func onePixelPNG() throws -> Data {
        let context = try #require(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}

/// Reads a zip of stored entries through its central directory, as an unzip tool would, and checks every
/// entry's local header and CRC along the way.
private enum ZipReader {
    struct Entry: Equatable {
        var name: String
        var contents: Data
    }

    struct Malformed: Error {}

    static func entries(of zip: Data) throws -> [Entry] {
        let zip = Data(zip)
        func u16(_ offset: Int) -> Int { Int(zip[offset]) | Int(zip[offset + 1]) << 8 }
        func u32(_ offset: Int) -> Int { u16(offset) | u16(offset + 2) << 16 }
        let end = zip.count - 22
        guard end >= 0, u32(end) == 0x0605_4B50 else { throw Malformed() }
        var cursor = u32(end + 16)
        var entries: [Entry] = []
        for _ in 0 ..< u16(end + 10) {
            guard u32(cursor) == 0x0201_4B50, u16(cursor + 10) == 0 else { throw Malformed() }
            let checksum = UInt32(u32(cursor + 16)), size = u32(cursor + 24), nameLength = u16(cursor + 28)
            let extra = u16(cursor + 30), comment = u16(cursor + 32), local = u32(cursor + 42)
            let name = String(decoding: zip[(cursor + 46) ..< (cursor + 46 + nameLength)], as: UTF8.self)
            guard u32(local) == 0x0403_4B50, u16(local + 26) == nameLength else { throw Malformed() }
            let start = local + 30 + nameLength + u16(local + 28)
            let contents = Data(zip[start ..< start + size])
            guard CRC32.checksum(contents) == checksum else { throw Malformed() }
            entries.append(Entry(name: name, contents: contents))
            cursor += 46 + nameLength + extra + comment
        }
        return entries
    }
}
