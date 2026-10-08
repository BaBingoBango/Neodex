import Foundation

/// Minimal RFC 4180 CSV reader (quoted fields, escaped quotes, embedded newlines).
/// Operates on UTF-8 bytes for speed; PokeAPI's larger files are 10+ MB.
struct CSVTable: Sendable {
    let header: [String]
    let rows: [[String]]
    private let columnIndex: [String: Int]

    init(data: Data) {
        var records: [[String]] = []
        var record: [String] = []
        var field: [UInt8] = []
        var inQuotes = false
        let bytes = [UInt8](data)
        var i = 0
        let count = bytes.count
        while i < count {
            let byte = bytes[i]
            if inQuotes {
                if byte == 0x22 { // "
                    if i + 1 < count, bytes[i + 1] == 0x22 {
                        field.append(0x22)
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(byte)
                }
            } else {
                switch byte {
                case 0x22: inQuotes = true
                case 0x2C: // ,
                    record.append(String(decoding: field, as: UTF8.self))
                    field.removeAll(keepingCapacity: true)
                case 0x0A: // \n
                    record.append(String(decoding: field, as: UTF8.self))
                    field.removeAll(keepingCapacity: true)
                    records.append(record)
                    record = []
                case 0x0D: break // \r
                default: field.append(byte)
                }
            }
            i += 1
        }
        if !field.isEmpty || !record.isEmpty {
            record.append(String(decoding: field, as: UTF8.self))
            records.append(record)
        }
        header = records.first ?? []
        rows = Array(records.dropFirst()).filter { !$0.allSatisfy(\.isEmpty) }
        columnIndex = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1, $0) })
    }

    /// Iterates rows as dictionaries keyed by column name.
    var dictionaries: [CSVRow] {
        rows.map { CSVRow(values: $0, columns: columnIndex) }
    }
}

struct CSVRow: Sendable {
    let values: [String]
    let columns: [String: Int]

    subscript(column: String) -> String {
        guard let index = columns[column], index < values.count else { return "" }
        return values[index]
    }

    func int(_ column: String) -> Int? { Int(self[column]) }
    func double(_ column: String) -> Double? { Double(self[column]) }
    func bool(_ column: String) -> Bool { self[column] == "1" }
    func string(_ column: String) -> String? {
        let value = self[column]
        return value.isEmpty ? nil : value
    }
}
