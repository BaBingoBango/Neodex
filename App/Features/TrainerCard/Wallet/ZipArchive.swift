import Foundation

/// A zip archive of uncompressed ("stored") entries at its top level, which is all a Wallet pass needs:
/// its PNGs are compressed already, and pass.json and the manifest are tiny.
nonisolated struct ZipArchive {
    private var entries = Data()
    private var centralDirectory = Data()
    private var count: UInt16 = 0

    /// 1980-01-01 00:00 in MS-DOS format, zip's earliest date. The archive is rebuilt on every update,
    /// so file dates carry nothing.
    private static let dosTime: UInt16 = 0
    private static let dosDate: UInt16 = 0x21

    /// Adds a file. Names are plain ASCII, like `icon@2x.png`.
    mutating func add(_ name: String, _ contents: Data) {
        let name = Data(name.utf8)
        let checksum = CRC32.checksum(contents)
        let offset = UInt32(entries.count)

        entries.appendLittleEndian(UInt32(0x0403_4B50)) // local file header
        entries.appendLittleEndian(UInt16(20)) // version needed to extract: 2.0
        appendSharedFields(to: &entries, checksum: checksum, size: contents.count, nameLength: name.count)
        entries.append(name)
        entries.append(contents)

        centralDirectory.appendLittleEndian(UInt32(0x0201_4B50)) // central directory header
        centralDirectory.appendLittleEndian(UInt16(20)) // version made by
        centralDirectory.appendLittleEndian(UInt16(20)) // version needed to extract
        appendSharedFields(to: &centralDirectory, checksum: checksum, size: contents.count, nameLength: name.count)
        centralDirectory.appendLittleEndian(UInt16(0)) // comment length
        centralDirectory.appendLittleEndian(UInt16(0)) // disk number
        centralDirectory.appendLittleEndian(UInt16(0)) // internal attributes
        centralDirectory.appendLittleEndian(UInt32(0)) // external attributes
        centralDirectory.appendLittleEndian(offset)
        centralDirectory.append(name)
        count += 1
    }

    /// The finished archive.
    var data: Data {
        var end = Data()
        end.appendLittleEndian(UInt32(0x0605_4B50)) // end of central directory
        end.appendLittleEndian(UInt16(0)) // this disk
        end.appendLittleEndian(UInt16(0)) // disk with the central directory
        end.appendLittleEndian(count) // entries on this disk
        end.appendLittleEndian(count) // entries in all
        end.appendLittleEndian(UInt32(centralDirectory.count))
        end.appendLittleEndian(UInt32(entries.count)) // where the central directory starts
        end.appendLittleEndian(UInt16(0)) // comment length
        return entries + centralDirectory + end
    }

    /// The fields from flags to extra-field length, which both headers share.
    private func appendSharedFields(to data: inout Data, checksum: UInt32, size: Int, nameLength: Int) {
        data.appendLittleEndian(UInt16(0)) // flags
        data.appendLittleEndian(UInt16(0)) // method: stored
        data.appendLittleEndian(Self.dosTime)
        data.appendLittleEndian(Self.dosDate)
        data.appendLittleEndian(checksum)
        data.appendLittleEndian(UInt32(size)) // compressed size
        data.appendLittleEndian(UInt32(size)) // uncompressed size
        data.appendLittleEndian(UInt16(nameLength))
        data.appendLittleEndian(UInt16(0)) // extra field length
    }
}

/// The CRC-32 zip and PNG both use (IEEE 802.3, reflected).
nonisolated enum CRC32 {
    private static let table: [UInt32] = (0 ..< 256).map { index in
        (0 ..< 8).reduce(UInt32(index)) { value, _ in value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1 }
    }

    static func checksum(_ data: Data) -> UInt32 {
        var value: UInt32 = 0xFFFF_FFFF
        for byte in data {
            value = table[Int((value ^ UInt32(byte)) & 0xFF)] ^ (value >> 8)
        }
        return value ^ 0xFFFF_FFFF
    }
}

nonisolated extension Data {
    mutating func appendLittleEndian<Value: FixedWidthInteger>(_ value: Value) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendBigEndian<Value: FixedWidthInteger>(_ value: Value) {
        Swift.withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }
}
