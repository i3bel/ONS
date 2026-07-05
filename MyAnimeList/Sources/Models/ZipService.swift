import Foundation

// MARK: - Minimal ZIP Service (pure Swift, no external dependencies)

/// Creates and extracts ZIP archives using store method (no compression).
/// Format: standard ZIP with local file headers + central directory.
enum ZipService {

    // MARK: - Create ZIP

    /// Create a ZIP archive from a source directory.
    /// - Parameters:
    ///   - sourceURL: Directory containing files to zip (e.g. temp export folder)
    ///   - destinationURL: Output `.zip` file URL
    static func createZip(from sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default

        // Gather all files with their relative paths
        var entries: [(path: String, data: Data)] = []
        guard let enumerator = fileManager.enumerator(at: sourceURL, includingPropertiesForKeys: [.isDirectoryKey]) else {
            throw ZipError.fileAccess
        }
        while let fileURL = enumerator.nextObject() as? URL {
            let isDir = try fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
            guard !isDir else { continue }
            let relativePath = String(fileURL.path.dropFirst(sourceURL.path.count + 1))
            let data = try Data(contentsOf: fileURL)
            entries.append((relativePath, data))
        }

        // Build ZIP archive
        var archive = Data()
        var centralDirectory = Data()
        var localHeaderOffsets: [UInt32] = []

        for (path, data) in entries {
            let localOffset = UInt32(archive.count)
            localHeaderOffsets.append(localOffset)
            let fileNameData = Data(path.utf8)
            let crc = crc32(data)
            let uncompressedSize = UInt32(data.count)

            // Local file header (30 bytes + filename)
            var localHeader = Data()
            localHeader.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // signature
            localHeader.append(contentsOf: [0x0A, 0x00]) // version needed
            localHeader.append(contentsOf: [0x00, 0x00]) // flags
            localHeader.append(contentsOf: [0x00, 0x00]) // compression: store
            localHeader.append(contentsOf: timeBits()) // mod time
            localHeader.append(contentsOf: dateBits()) // mod date
            localHeader.append(contentsOf: crc.littleEndianBytes)
            localHeader.append(contentsOf: uncompressedSize.littleEndianBytes) // compressed size (same for store)
            localHeader.append(contentsOf: uncompressedSize.littleEndianBytes) // uncompressed size
            localHeader.append(contentsOf: UInt16(fileNameData.count).littleEndianBytes)
            localHeader.append(contentsOf: [0x00, 0x00]) // extra field length
            localHeader.append(fileNameData)

            archive.append(localHeader)
            archive.append(data)

            // Central directory entry (46 bytes + filename)
            var cdEntry = Data()
            cdEntry.append(contentsOf: [0x50, 0x4B, 0x01, 0x02]) // signature
            cdEntry.append(contentsOf: [0x3F, 0x00]) // version made by
            cdEntry.append(contentsOf: [0x0A, 0x00]) // version needed
            cdEntry.append(contentsOf: [0x00, 0x00]) // flags
            cdEntry.append(contentsOf: [0x00, 0x00]) // compression: store
            cdEntry.append(contentsOf: timeBits()) // mod time
            cdEntry.append(contentsOf: dateBits()) // mod date
            cdEntry.append(contentsOf: crc.littleEndianBytes)
            cdEntry.append(contentsOf: uncompressedSize.littleEndianBytes)
            cdEntry.append(contentsOf: uncompressedSize.littleEndianBytes)
            cdEntry.append(contentsOf: UInt16(fileNameData.count).littleEndianBytes)
            cdEntry.append(contentsOf: [0x00, 0x00]) // extra field length
            cdEntry.append(contentsOf: [0x00, 0x00]) // file comment length
            cdEntry.append(contentsOf: [0x00, 0x00]) // disk number start
            cdEntry.append(contentsOf: [0x00, 0x00]) // internal attrs
            cdEntry.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // external attrs
            cdEntry.append(contentsOf: localOffset.littleEndianBytes) // local header offset
            cdEntry.append(fileNameData)

            centralDirectory.append(cdEntry)
        }

        // End of central directory record (22 bytes)
        let cdOffset = UInt32(archive.count)
        var eocd = Data()
        eocd.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // signature
        eocd.append(contentsOf: [0x00, 0x00]) // disk number
        eocd.append(contentsOf: [0x00, 0x00]) // disk with start of CD
        eocd.append(contentsOf: UInt16(entries.count).littleEndianBytes) // entries on this disk
        eocd.append(contentsOf: UInt16(entries.count).littleEndianBytes) // total entries
        eocd.append(contentsOf: UInt32(centralDirectory.count).littleEndianBytes) // CD size
        eocd.append(contentsOf: cdOffset.littleEndianBytes) // CD offset
        eocd.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // comment length

        archive.append(centralDirectory)
        archive.append(eocd)

        try archive.write(to: destinationURL, options: .atomic)
    }

    // MARK: - Extract ZIP

    /// Extract a ZIP archive to a destination directory.
    static func extractZip(from sourceURL: URL, to destinationURL: URL) throws {
        let data = try Data(contentsOf: sourceURL)
        let bytes = [UInt8](data)

        // Parse central directory to find all entries
        // First, find End of Central Directory
        guard let eocdStart = findEOCD(in: bytes) else { throw ZipError.invalidArchive }
        let cdOffset = UInt32(bytes[eocdStart + 16], bytes[eocdStart + 17], bytes[eocdStart + 18], bytes[eocdStart + 19])
        let cdSize = UInt32(bytes[eocdStart + 12], bytes[eocdStart + 13], bytes[eocdStart + 14], bytes[eocdStart + 15])

        // Parse central directory entries
        let cdEnd = Int(cdOffset + cdSize)
        var entries: [(path: String, localOffset: UInt32)] = []
        var pos = Int(cdOffset)
        while pos + 46 <= cdEnd {
            let sig = UInt32(bytes[pos], bytes[pos+1], bytes[pos+2], bytes[pos+3])
            guard sig == 0x02014B50 else { break }
            let nameLen = Int(UInt16(bytes[pos+28], bytes[pos+29]))
            let extraLen = Int(UInt16(bytes[pos+30], bytes[pos+31]))
            let localOffset = UInt32(bytes[pos+42], bytes[pos+43], bytes[pos+44], bytes[pos+45])
            let nameStart = pos + 46
            guard nameStart + nameLen <= bytes.count else { break }
            let name = String(bytes: Array(bytes[nameStart..<nameStart+nameLen]), encoding: .utf8) ?? ""
            entries.append((name, localOffset))
            pos = nameStart + nameLen + extraLen
        }

        // Extract each file from local headers
        var extractedFiles: [String] = []
        for (path, localOffset) in entries {
            // Parse local file header
            let lo = Int(localOffset)
            guard lo + 30 <= bytes.count else { continue }
            let nameLen = Int(UInt16(bytes[lo+26], bytes[lo+27]))
            let extraLen = Int(UInt16(bytes[lo+28], bytes[lo+29]))
            let dataStart = lo + 30 + nameLen + extraLen

            // Read compressed size from local header
            let compSize = Int(UInt32(bytes[lo+18], bytes[lo+19], bytes[lo+20], bytes[lo+21]))
            let dataEnd = dataStart + compSize

            guard dataStart <= bytes.count, dataEnd <= bytes.count else { continue }

            let fileData = Data(bytes[dataStart..<dataEnd])
            let destFile = destinationURL.appendingPathComponent(path)

            // Create subdirectories if needed
            try FileManager.default.createDirectory(at: destFile.deletingLastPathComponent(), withIntermediateDirectories: true)

            try fileData.write(to: destFile, options: .atomic)
            extractedFiles.append(path)
        }

        guard !extractedFiles.isEmpty else { throw ZipError.emptyArchive }
    }

    // MARK: - Helpers

    private static func findEOCD(in bytes: [UInt8]) -> Int? {
        // Search backwards for EOCD signature 0x06054B50
        let start = max(0, bytes.count - 65557)
        var pos = bytes.count - 22
        while pos >= start {
            if pos + 3 < bytes.count,
               bytes[pos] == 0x50, bytes[pos+1] == 0x4B,
               bytes[pos+2] == 0x05, bytes[pos+3] == 0x06 {
                return pos
            }
            pos -= 1
        }
        return nil
    }

    // MARK: - CRC-32 (pure Swift)

    private static func crc32(_ data: Data) -> UInt32 {
        var table: [UInt32] = Array(repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (0xEDB88320 ^ (crc >> 1)) : (crc >> 1)
            }
            table[i] = crc
        }
        var result: UInt32 = 0xFFFFFFFF
        for byte in data {
            result = table[Int((result ^ UInt32(byte)) & 0xFF)] ^ (result >> 8)
        }
        return result ^ 0xFFFFFFFF
    }

    private static func timeBits() -> [UInt8] {
        let now = Date()
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        let h = UInt16(comps.hour ?? 0) << 11
        let m = UInt16(comps.minute ?? 0) << 5
        let s = UInt16(comps.second ?? 0) >> 1
        let val = h | m | s
        return [UInt8(val & 0xFF), UInt8((val >> 8) & 0xFF)]
    }

    private static func dateBits() -> [UInt8] {
        let now = Date()
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
        let y = UInt16((comps.year ?? 2026) - 1980) << 9
        let m = UInt16(comps.month ?? 1) << 5
        let d = UInt16(comps.day ?? 1)
        let val = y | m | d
        return [UInt8(val & 0xFF), UInt8((val >> 8) & 0xFF)]
    }
}

// MARK: - Errors

enum ZipError: Error, LocalizedError {
    case fileAccess
    case invalidArchive
    case emptyArchive

    var errorDescription: String? {
        switch self {
        case .fileAccess: return "Cannot access files"
        case .invalidArchive: return "Invalid ZIP archive"
        case .emptyArchive: return "ZIP archive is empty"
        }
    }
}

// MARK: - UInt / UInt16 / UInt32 helpers

private extension UInt16 {
    var littleEndianBytes: [UInt8] {
        [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF)]
    }

    init(_ b0: UInt8, _ b1: UInt8) {
        self = UInt16(b0) | (UInt16(b1) << 8)
    }
}

private extension UInt32 {
    var littleEndianBytes: [UInt8] {
        [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 24) & 0xFF)]
    }

    init(_ b0: UInt8, _ b1: UInt8, _ b2: UInt8, _ b3: UInt8) {
        self = UInt32(b0) | (UInt32(b1) << 8) | (UInt32(b2) << 16) | (UInt32(b3) << 24)
    }
}
