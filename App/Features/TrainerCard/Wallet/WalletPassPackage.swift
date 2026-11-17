import CryptoKit
import Foundation

/// A Wallet pass built on the device.
///
/// Wallet checks a pass through one signature over `manifest.json`, which lists the SHA-1 hash of every
/// other file. So the signing server only ever needs the manifest, and the trainer's name, picture, team
/// and city never leave the device (see `Server/README.md`).
nonisolated struct WalletPassPackage: Sendable {
    /// The pass's files at the top level of the archive, such as `pass.json` and `thumbnail@2x.png`.
    let files: [String: Data]
    /// The exact bytes the server signs and the archive carries.
    let manifest: Data

    init(files: [String: Data]) throws {
        self.files = files
        let digests = files.mapValues { contents in
            Insecure.SHA1.hash(data: contents).map { String(format: "%02x", $0) }.joined()
        }
        manifest = try JSONSerialization.data(withJSONObject: digests, options: [.sortedKeys])
    }

    /// The `.pkpass` Wallet opens: the pass's files, the manifest and the server's signature of it.
    func archive(signature: Data) -> Data {
        var zip = ZipArchive()
        for (name, contents) in files.sorted(by: { $0.key < $1.key }) {
            zip.add(name, contents)
        }
        zip.add("manifest.json", manifest)
        zip.add("signature", signature)
        return zip.data
    }
}

/// Random bytes inside a PNG that no viewer shows. Each of a pass's images carries one, so the hashes the
/// signing server sees can't be matched against the hashes of known sprites or artwork.
nonisolated enum PNGNonce {
    private static let signature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    /// The same image with a `tEXt` chunk holding a random value right after its header, or nil if the data
    /// isn't a PNG.
    static func adding(to png: Data, nonce: String = UUID().uuidString) -> Data? {
        let png = Data(png) // index from zero
        // A PNG opens with its 8-byte signature and the IHDR chunk: length, type, 13 bytes of data, CRC.
        guard png.count > 33, png.prefix(8) == signature, png[12 ..< 16] == Data("IHDR".utf8),
              png[8 ..< 12].reduce(0, { $0 << 8 | Int($1) }) == 13 else { return nil }
        var typeAndData = Data("tEXt".utf8)
        typeAndData.append(Data("Comment".utf8))
        typeAndData.append(0) // keyword terminator
        typeAndData.append(Data(nonce.utf8))
        var chunk = Data()
        chunk.appendBigEndian(UInt32(typeAndData.count - 4))
        chunk.append(typeAndData)
        chunk.appendBigEndian(CRC32.checksum(typeAndData))
        return png[..<33] + chunk + png[33...]
    }
}
